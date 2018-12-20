package bz.rxla.audioplayer;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Handler;
import android.util.Log;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import java.io.IOException;
import java.util.HashMap;

import android.content.Context;
import android.os.Build;

/**
 * Android implementation for AudioPlayerPlugin.
 */
public class AudioplayerPlugin implements MethodCallHandler {
  private static final String ID = "bz.rxla.flutter/audio";

  private final MethodChannel channel;
  private final AudioManager am;
  private final Handler handler = new Handler();
  private MediaPlayer mediaPlayer;


  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), ID);
    channel.setMethodCallHandler(new AudioplayerPlugin(registrar, channel));
  }

  private AudioplayerPlugin(Registrar registrar, MethodChannel channel) {
    this.channel = channel;
    channel.setMethodCallHandler(this);
    Context context = registrar.context().getApplicationContext();
    this.am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
  }


  /**
   * 焦点变化监听器
   */
  private AudioManager.OnAudioFocusChangeListener mAudioFocusChange = new AudioManager.OnAudioFocusChangeListener() {
    @Override
    public void onAudioFocusChange(int focusChange) {
        String TAG="AudioManager";
      switch (focusChange){
        case AudioManager.AUDIOFOCUS_LOSS:
          //长时间丢失焦点
          Log.d(TAG, "AUDIOFOCUS_LOSS");
          //释放焦点
          am.abandonAudioFocus(mAudioFocusChange);
          channel.invokeMethod("audio.AUDIOFOCUS_LOSS", null);
          break;
        case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
          //短暂性丢失焦点
          Log.d(TAG, "AUDIOFOCUS_LOSS_TRANSIENT");
          channel.invokeMethod("audio.AUDIOFOCUS_LOSS_TRANSIENT", null);
          break;
        case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
          //短暂性丢失焦点并作降音处理
          Log.d(TAG, "AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK");
          channel.invokeMethod("audio.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK", null);
          break;
        case AudioManager.AUDIOFOCUS_GAIN:
          //重新获得焦点
          channel.invokeMethod("audio.AUDIOFOCUS_GAIN", null);
          Log.d(TAG, "AUDIOFOCUS_GAIN");
          break;
      }
    }
  };


  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result response) {
    switch (call.method) {
      case "play":
        play(call.argument("url").toString());
        response.success(null);
        break;
      case "pause":
        pause();
        response.success(null);
        break;
      case "stop":
        stop();
        response.success(null);
        break;
      case "seek":
        double position = call.arguments();
        seek(position);
        response.success(null);
        break;
      case "mute":
        Boolean muted = call.arguments();
        mute(muted);
        response.success(null);
        break;
      default:
        response.notImplemented();
    }
  }

  private void mute(Boolean muted) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      am.adjustStreamVolume(AudioManager.STREAM_MUSIC, muted ? AudioManager.ADJUST_MUTE : AudioManager.ADJUST_UNMUTE, 0);
    } else {
      am.setStreamMute(AudioManager.STREAM_MUSIC, muted);
    }
  }

  private void seek(double position) {
    mediaPlayer.seekTo((int) (position * 1000));
  }

  private void stop() {
    handler.removeCallbacks(sendData);
    if (mediaPlayer != null) {
      mediaPlayer.stop();
      mediaPlayer.release();
      mediaPlayer = null;
      am.requestAudioFocus(mAudioFocusChange, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
      channel.invokeMethod("audio.onStop", null);
    }
  }

  private void pause() {
    handler.removeCallbacks(sendData);
    if (mediaPlayer != null) {
      mediaPlayer.pause();
      channel.invokeMethod("audio.onPause", true);
    }
  }

  private void play(String url) {

      if (mediaPlayer == null) {
          mediaPlayer = new MediaPlayer();
          am.requestAudioFocus(mAudioFocusChange, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);


          AudioAttributes audioAttribute = new AudioAttributes.Builder()
              .setUsage(AudioAttributes.USAGE_MEDIA)
              .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
              .build();

          mediaPlayer.setAudioAttributes(audioAttribute);
          //mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);


          channel.invokeMethod("audio.onLoading",null);

          try {
              mediaPlayer.setDataSource(url);
          } catch (IOException e) {
              Log.w(ID, "Invalid DataSource", e);
              channel.invokeMethod("audio.onError", "Invalid Datasource");
              return;
          }

          mediaPlayer.prepareAsync();


          mediaPlayer.setOnPreparedListener(new MediaPlayer.OnPreparedListener(){
              @Override
              public void onPrepared(MediaPlayer mp) {
                  mediaPlayer.start();
                  channel.invokeMethod("audio.onStart", mediaPlayer.getDuration());
              }
          });

          mediaPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener(){
              @Override
              public void onCompletion(MediaPlayer mp) {
                  stop();
                  channel.invokeMethod("audio.onComplete", null);
              }
          });

          mediaPlayer.setOnErrorListener(new MediaPlayer.OnErrorListener(){
              @Override
              public boolean onError(MediaPlayer mp, int what, int extra) {
                  channel.invokeMethod("audio.onError", String.format("{\"what\":%d,\"extra\":%d}", what, extra));
                  return true;
              }
          });
      } else {
          //直接播放
          mediaPlayer.start();
          channel.invokeMethod("audio.onStart", mediaPlayer.getDuration());
      }
      handler.post(sendData);
  }

  private final Runnable sendData = new Runnable(){
      public void run(){
          try {
              if (!mediaPlayer.isPlaying()) {
                  handler.removeCallbacks(sendData);
              }
              int time = mediaPlayer.getCurrentPosition();
              channel.invokeMethod("audio.onCurrentPosition", time);
              handler.postDelayed(this, 200);
          }
          catch (Exception e) {
              Log.w(ID, "When running handler", e);
          }
      }
  };
}
