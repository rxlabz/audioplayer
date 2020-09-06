package bz.rxla.audioplayer;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.graphics.drawable.Icon;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaDescription;
import android.media.MediaMetadata;
import android.media.MediaPlayer;
import android.media.browse.MediaBrowser;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.PowerManager;
import android.os.ResultReceiver;
import android.os.SystemClock;
import android.service.media.MediaBrowserService;
import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import androidx.annotation.RequiresApi;
import android.media.AudioFocusRequest;
import android.view.KeyEvent;

import androidx.media.MediaBrowserServiceCompat;

/**
 * Android implementation for AudioPlayerPlugin.
 */
public class AudioplayerPlugin extends MediaBrowserService implements FlutterPlugin, MethodCallHandler {
  private static final String ID = "bz.rxla.flutter/audio";
  private static final int REQUEST_CODE = 100;
  private static final String MEDIA_ROOT_ID = "root";
  private static final String TAG="AudioFocusTEST";
  private static final String CMD_NAME = "command";
  private static final String CMD_PAUSE = "pause";
  private static final String CMD_STOP = "pause";
  private static final String CMD_PLAY = "play";
  // Jellybean
  private static String SERVICE_CMD = "com.sec.android.app.music.musicservicecommand";
  private static String PAUSE_SERVICE_CMD = "com.sec.android.app.music.musicservicecommand.pause";
  private static String PLAY_SERVICE_CMD = "com.sec.android.app.music.musicservicecommand.play";
  // Honeycomb
  {
    if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.JELLY_BEAN) {
      SERVICE_CMD = "com.android.music.musicservicecommand";
      PAUSE_SERVICE_CMD = "com.android.music.musicservicecommand.pause";
      PLAY_SERVICE_CMD = "com.android.music.musicservicecommand.play";
    }
  };
  public static final int KEYCODE_BYPASS_PLAY = KeyEvent.KEYCODE_MUTE;
  public static final int KEYCODE_BYPASS_PAUSE = KeyEvent.KEYCODE_MEDIA_RECORD;
  private Context mContext;
  private MethodChannel channel;
  private AudioManager am;
  private final Handler handler = new Handler();
  private String currentPlayingURRL;
  private boolean mAudioFocusGranted=false;
  private boolean isPlaying=false;
  private MediaPlayer mediaPlayer;
  private Object audioFocusRequest;
  private MediaSessionCompat mediaSession;
  private PowerManager.WakeLock wakeLock;
  private AudioManager.OnAudioFocusChangeListener mOnAudioFocusChangeListener;
  private BroadcastReceiver mIntentReceiver;
  private boolean mReceiverRegistered = false;
  private MediaNotificationManager notificationManager;
  private NotificationManager mNotificationManager;
  AudioplayerPlugin AudioplayerPlugininstance;
  //sessions related

  private MediaSession mSession;
  private int mState = PlaybackState.STATE_NONE;
  private List<MediaSession.QueueItem> mPlayingQueue;
  private int mCurrentIndexOnQueue;

  //Notification intents

  private Notification.Action mPlayAction;
  private Notification.Action mPauseAction;
  private Notification.Action mNextAction;
  private Notification.Action mPrevAction;
  private String channelID="channelNotification";

  //Notification item metaData

  private String itemTitle;
  private String itemAuthor;
  private String itemAlbum;
  private String itemAlbumArt;

  //Notification metadata
  private boolean useNotification;
  private boolean onlyShowWhenPlaying;

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), ID);
    AudioplayerPlugin instance = new AudioplayerPlugin(registrar);
    instance.initInstance(registrar.messenger(), registrar.context());
  }

  private void initInstance(BinaryMessenger binaryMessenger, Context context) {
    this.channel = new MethodChannel(binaryMessenger, ID);
    this.channel.setMethodCallHandler(this);
    am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
  }


  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    this.channel = null;
    am = null;
  }

  private AudioplayerPlugin(Registrar registrar) {
    Context context = registrar.context().getApplicationContext();
    mContext=context;
    mNotificationManager = (NotificationManager) context
            .getSystemService(Context.NOTIFICATION_SERVICE);
    mOnAudioFocusChangeListener = new AudioManager.OnAudioFocusChangeListener() {
      @Override
      public void onAudioFocusChange(int focusChange) {
        switch (focusChange) {
          case AudioManager.AUDIOFOCUS_GAIN:
            Log.i(TAG, "AUDIOFOCUS_GAIN");
            invokeFocusGained();
            break;
          case AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE:
            Log.i(TAG, "AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE");
            invokeFocusGained();
            break;
          case AudioManager.AUDIOFOCUS_GAIN_TRANSIENT:
            invokeFocusGained();
            Log.i(TAG, "AUDIOFOCUS_GAIN_TRANSIENT");
            break;
          case AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK:
            Log.i(TAG, "AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK");
            break;
          case AudioManager.AUDIOFOCUS_LOSS:
            Log.e(TAG, "AUDIOFOCUS_LOSS");
            invokeFocusLost();
            pause();
            break;
          case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
            Log.e(TAG, "AUDIOFOCUS_LOSS_TRANSIENT");
            invokeFocusLost();
            pause();
            break;
          case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
            Log.e(TAG, "AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK");
            break;
          case AudioManager.AUDIOFOCUS_REQUEST_FAILED:
            Log.e(TAG, "AUDIOFOCUS_REQUEST_FAILED");
            break;
          default:
//
        }
      }
    };
    setupBroadcastReceiver();
    startSession(mContext);
  }

  // On destroy method :


  @Override
  public void onDestroy() {
    mSession.release();
    handleStopRequest(null);
    unSetupBroadcastReceiver();
    super.onDestroy();
  }



  public void invokeFocusGained(){
    channel.invokeMethod("audio.onAudioFocusGained",null);
  }

  public void invokeFocusLost(){
    channel.invokeMethod("audio.onAudioFocusLost",null);
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result response) {
    switch (call.method) {
      case "play":
        Object url = call.argument("url");
        String playTitle  = call.argument("title");
        String playAuthor  = call.argument("author");
        String playAlbumArt  = call.argument("albumArt");
        String playAlbum  = call.argument("album");
        if (url instanceof String) {
          setItem(playTitle,playAuthor,playAlbum,playAlbumArt);
          play((String) url);
        } else {
          play("");
        }
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
      case "setItem":
        String title  = call.argument("title");
        String author  = call.argument("author");
        String albumArt  = call.argument("albumArt");
        String album  = call.argument("album");
        setItem(title,author,album,albumArt);
        response.success(null);
        break;
      case "useNotification":
        boolean useNotification  = call.argument("useNotification");
        boolean onlyShowWhenPlaying  = call.argument("onlyShowWhenPlaying");
        useNotification(useNotification, onlyShowWhenPlaying);
        response.success(null);
        break;
      case "showNotification":
        showNotification();
        response.success(null);
        break;
      case "hideNotification":
        hideNotification();
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
    UpdateNotificationManager();
  }

  private void seek(double position) {
    mediaPlayer.seekTo((int) (position * 1000));
    UpdateNotificationManager();
  }

   void stop() {
    handler.removeCallbacks(sendData);
    if (mediaPlayer != null) {
      mediaPlayer.stop();
      mediaPlayer.release();
      mediaPlayer = null;
      channel.invokeMethod("audio.onStop", null);
      isPlaying=false;
      abandonAudioFocus();
      mState=PlaybackState.STATE_STOPPED;
      updatePlaybackState(null);
      UpdateNotificationManager();
    }

  }

   void pause() {
    handler.removeCallbacks(sendData);
    if (mediaPlayer != null) {
      mediaPlayer.pause();
      channel.invokeMethod("audio.onPause", true);
      isPlaying=false;
      abandonAudioFocus();
      mState=PlaybackState.STATE_PAUSED;
      updatePlaybackState(null);
      UpdateNotificationManager();
    }
  }

  void setItem(String title, String author, String album, String albumArt){
    this.itemTitle=title;
    this.itemAlbum=album;
    this.itemAlbumArt=albumArt;
    this.itemAuthor=author;
  }

  void showNotification(){
    this.UpdateNotificationManager();
  }
  void useNotification(boolean use, boolean onlyShowWhenPlaying){
    this.useNotification=use;
    this.onlyShowWhenPlaying=onlyShowWhenPlaying;
  }
  void hideNotification(){
    this.notificationManager.hideNotification();
  }

  void playCurrentOnly(){
    if(currentPlayingURRL!=null){
      play(currentPlayingURRL);
    }
  }
   void play(String url) {
    currentPlayingURRL =url;
    int result;
    if(!isPlaying){
      result = requestAudioFocus();
      //The focus gained channel invoke is used here since the listener doesn't trigger the audioFocus gained Listener
      // It basically doesn't trigger the onAudioFocusChange method at all
      invokeFocusGained();
    }else{
      result=1;
    }
    if(result ==AudioManager.AUDIOFOCUS_REQUEST_GRANTED){
      if (mediaPlayer == null) {
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);

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
            //will abandon audio focus when play ends
            abandonAudioFocus();
            channel.invokeMethod("audio.onComplete", null);
          }
        });

        mediaPlayer.setOnErrorListener(new MediaPlayer.OnErrorListener(){
          @Override
          public boolean onError(MediaPlayer mp, int what, int extra) {
            //will abandon focus when error
            abandonAudioFocus();
            channel.invokeMethod("audio.onError", String.format("{\"what\":%d,\"extra\":%d}", what, extra));
            return true;
          }
        });
      } else {
        mediaPlayer.start();
        channel.invokeMethod("audio.onStart", mediaPlayer.getDuration());
      }
      isPlaying=true;
      handler.post(sendData);
      mState=PlaybackState.STATE_PLAYING;
      updatePlaybackState(null);
      UpdateNotificationManager();
    }
  }

  void UpdateNotificationManager(){
    if(!useNotification) return;
    if(notificationManager==null){
      if(Build.VERSION.SDK_INT > 25){
        notificationManager = new OreoMediaNotificationManager(this,mContext,onlyShowWhenPlaying);
      }else{
        notificationManager = new MediaNotificationManager(this,mContext,onlyShowWhenPlaying);
      }

    }
    MediaMetadata newMetadata = new MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, this.itemTitle)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, this.itemAlbum)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, this.itemAuthor)
            .putString(MediaMetadata.METADATA_KEY_AUTHOR, this.itemAuthor)
            .putString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI, this.itemAlbumArt)
            .build();

    long position = PlaybackState.PLAYBACK_POSITION_UNKNOWN;
    if (mediaPlayer != null && mediaPlayer.isPlaying()) {
      position = mediaPlayer.getCurrentPosition();
    }
    notificationManager.update(newMetadata,new PlaybackState.Builder().setState(mState, position, 1.0f, SystemClock.elapsedRealtime()).build(),mSession.getSessionToken());
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

  private int requestAudioFocus() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
      return requestAudioFocusO();
    else
      return am.requestAudioFocus(mOnAudioFocusChangeListener,
              AudioManager.STREAM_MUSIC,
              AudioManager.AUDIOFOCUS_GAIN);
  }

  @RequiresApi(Build.VERSION_CODES.O)
  private int requestAudioFocusO() {
    AudioAttributes audioAttributes = new AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build();
    audioFocusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(audioAttributes)
            .setWillPauseWhenDucked(true)
            .setOnAudioFocusChangeListener(mOnAudioFocusChangeListener)
            .build();
    return am.requestAudioFocus((AudioFocusRequest)audioFocusRequest);
  }

  private void abandonAudioFocus() {
    int result = am.abandonAudioFocus(mOnAudioFocusChangeListener);
    if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
      mAudioFocusGranted = false;
    } else {
// FAILED
      Log.e(TAG,
              ">>>>>>>>>>>>> FAILED TO ABANDON AUDIO FOCUS <<<<<<<<<<<<<<<<<<<<<<<<");
    }
  }

  //The broadcast receiver is taking care only of the unplugged headphone event
  //The other actions only count for old android versions support
  private void setupBroadcastReceiver() {
    mIntentReceiver = new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        String cmd = intent.getStringExtra(CMD_NAME);
        if (PAUSE_SERVICE_CMD.equals(action)
                || (SERVICE_CMD.equals(action) && CMD_PAUSE.equals(cmd))) {
          if(currentPlayingURRL!=null){
            play(currentPlayingURRL);
          }
        }
        if (PLAY_SERVICE_CMD.equals(action)
                || (SERVICE_CMD.equals(action) && CMD_PLAY.equals(cmd))) {
          pause();
        }
          if (AudioManager.ACTION_AUDIO_BECOMING_NOISY.equals(action)) {
              //headphones unplugged
              pause();
          }
      }
    };
// Do the right thing when something else tries to play
    if (!mReceiverRegistered) {
      IntentFilter commandFilter = new IntentFilter();
      commandFilter.addAction(SERVICE_CMD);
      commandFilter.addAction(PAUSE_SERVICE_CMD);
      commandFilter.addAction(PLAY_SERVICE_CMD);
      commandFilter.addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY);
      mContext.registerReceiver(mIntentReceiver, commandFilter);
      mReceiverRegistered = true;
    }
  }

  private void unSetupBroadcastReceiver(){
      if(mReceiverRegistered){
          mContext.unregisterReceiver(mIntentReceiver);
      }
  }

  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  private void startSession(Context context){
    mSession = new MediaSession(context, "MusicService");
    setSessionToken(mSession.getSessionToken());
    mSession.setCallback(new MediaSession.Callback() {

      @Override
      public void onPlay() {
        Log.d(TAG, "play");
        /*if (mPlayingQueue == null || mPlayingQueue.isEmpty()) {
          mSession.setQueue(mPlayingQueue);
          mSession.setQueueTitle(getString(R.string.random_queue_title));
          // start playing from the beginning of the queue
          mCurrentIndexOnQueue = 0;
        }
        if (mPlayingQueue != null && !mPlayingQueue.isEmpty()) {
          handlePlayRequest();
        }*/

        if(isPlaying){
          pause();
          channel.invokeMethod("audio.onPlayPauseKey", false);
        }else{
          if(currentPlayingURRL!=null){
            play(currentPlayingURRL);
            channel.invokeMethod("audio.onPlayPauseKey", true);
          }
        }

      }

      @Override
      public void onPause() {
        Log.d(TAG, "pause");
          channel.invokeMethod("audio.onKeyPause", true);
        pause();
      }

      @Override
      public void onSkipToNext() {
        Log.d(TAG, "skipNext");
        //Will be implemented as an event to the plugin side
          channel.invokeMethod("audio.onKeySkipToNext", true);
      }



      @Override
      public boolean onMediaButtonEvent(@NonNull Intent mediaButtonIntent) {
        //THis will take care of the extra buttons and button combinations
        final KeyEvent event = (KeyEvent)mediaButtonIntent.getExtras().get(Intent.EXTRA_KEY_EVENT);
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
          switch (event.getKeyCode()) {
            case KEYCODE_BYPASS_PLAY:
              onPlay();
              break;
            case KEYCODE_BYPASS_PAUSE:
              onPause();
              break;
            case KeyEvent.KEYCODE_MEDIA_NEXT:
              onSkipToNext();
              break;
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
              onSkipToPrevious();
              break;
            case KeyEvent.KEYCODE_MEDIA_STOP:
              onStop();
              break;
            case KeyEvent.KEYCODE_MEDIA_FAST_FORWARD:
              onFastForward();
              break;
            case KeyEvent.KEYCODE_MEDIA_REWIND:
              onRewind();
              break;
            // Android unfortunately reroutes media button clicks to
            // KEYCODE_MEDIA_PLAY/PAUSE instead of the expected KEYCODE_HEADSETHOOK
            // or KEYCODE_MEDIA_PLAY_PAUSE. As a result, we can't genuinely tell if
            // onMediaButtonEvent was called because a media button was actually
            // pressed or because a PLAY/PAUSE action was pressed instead! To get
            // around this, we make PLAY and PAUSE actions use different keycodes:
            // KEYCODE_BYPASS_PLAY/PAUSE. Now if we get KEYCODE_MEDIA_PLAY/PUASE
            // we know it is actually a media button press.
            case KeyEvent.KEYCODE_MEDIA_PLAY:
            case KeyEvent.KEYCODE_MEDIA_PAUSE:
              // These are the "genuine" media button click events
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
            case KeyEvent.KEYCODE_HEADSETHOOK:
              break;
          }
        }
        return true;
      }

      @Override
      public void onSkipToPrevious() {
        Log.d(TAG, "skipPrevious");
        //Will be implemented as an event to the plugin side
          channel.invokeMethod("audio.onKeySkipToPrevious", true);
      }

      @Override
      public void onFastForward() {
        //Will be implemented as an event to the plugin side
          channel.invokeMethod("audio.onKeyFastForward", true);
      }

      @Override
      public void onRewind() {
        //Will be implemented as an event to the plugin side
          channel.invokeMethod("audio.onKeyRewind", true);
      }

      @Override
      public void onStop() {
        Log.d(TAG, "Stop");
          channel.invokeMethod("audio.onKeyStop", true);
        stop();
      }

      @Override
      public void onSeekTo(long pos) {
        Log.d(TAG, "Seek");
          channel.invokeMethod("audio.onKeySeekTo", pos);
        seek((double)pos);
      }

      @Override
      public void onSkipToQueueItem(long id) {
        Log.d(TAG, "onSkipToQueueItem: ");
      }
    });
    mSession.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS |
            MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS);
    updatePlaybackState(null);
    //mMediaNotification = new MediaNotification(this);
    mSession.setActive(true);
    Log.d(TAG, "startSession: STARTING THE SESSION");
  }

  //The next and previous skip are not handled by the plugin so they are reported to the main app
  void onSkipToNext(){
    channel.invokeMethod("audio.onKeySkipToNext", true);
  }

  void onSkipToPrevious(){
    channel.invokeMethod("audio.onKeySkipToPrevious", true);
  }

  @Nullable
  @Override
  public BrowserRoot onGetRoot(@NonNull String s, int i, @Nullable Bundle bundle) {
    return null;
  }

  @Override
  public void onLoadChildren(@NonNull String s, @NonNull Result<List<MediaBrowser.MediaItem>> result) {

  }
  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  private void updatePlaybackState(String error) {
    long position = PlaybackState.PLAYBACK_POSITION_UNKNOWN;
    if (mediaPlayer != null && mediaPlayer.isPlaying()) {
      position = mediaPlayer.getCurrentPosition();
    }
    PlaybackState.Builder stateBuilder = new PlaybackState.Builder()
            .setActions(getAvailableActions());
    //The following custom action should be implemented as a return to the plugin side to finish the favorite or the thumbsUp
    /*setCustomAction(stateBuilder);*/
    // If there is an error message, send it to the playback state:
    if (error != null) {
      // Error states are really only supposed to be used for errors that cause playback to
      // stop unexpectedly and persist until the user takes action to fix it.
      stateBuilder.setErrorMessage(error);
      mState = PlaybackState.STATE_ERROR;
    }
    stateBuilder.setState(mState, position, 1.0f, SystemClock.elapsedRealtime());
    mSession.setPlaybackState(stateBuilder.build());
    //The notification part is not going to be implemented right now with this plugin
    /*if (mState == PlaybackState.STATE_PLAYING || mState == PlaybackState.STATE_PAUSED) {
      mMediaNotification.startNotification();
    }*/
  }

  //Helper Functions to handle audio management
  //

  /**
   * Returns the Available actions with each state
   * @return
   */
  private long getAvailableActions() {
    long actions = PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PLAY_FROM_MEDIA_ID |
            PlaybackState.ACTION_PLAY_FROM_SEARCH;
    if (mPlayingQueue == null || mPlayingQueue.isEmpty()) {
      return actions;
    }
    if (mState == PlaybackState.STATE_PLAYING) {
      actions |= PlaybackState.ACTION_PAUSE;
    }

    //Since we don't manage queue from this plugin these will be discarded
   /* if (mCurrentIndexOnQueue > 0) {
      actions |= PlaybackState.ACTION_SKIP_TO_PREVIOUS;
    }
    if (mCurrentIndexOnQueue < mPlayingQueue.size() - 1) {
      actions |= PlaybackState.ACTION_SKIP_TO_NEXT;
    }*/
    actions |= PlaybackState.ACTION_SKIP_TO_PREVIOUS;
    actions |= PlaybackState.ACTION_SKIP_TO_NEXT;

    return actions;
  }

  /**
   * Will handle the playbakc stopping request, releasing session
   * @param withError
   */
  private void handleStopRequest(String withError) {
    Log.d(TAG, "handleStopRequest: mState=" + mState + " error=" + withError );
    mState = PlaybackState.STATE_STOPPED;
    updatePlaybackState(null);
    // let go of all resources...
    relaxResources(true);
    abandonAudioFocus();
    updatePlaybackState(withError);
    //The notification handler is not implemented here
    //mMediaNotification.stopNotification();
    // service is no longer necessary. Will be started again if needed.
    stopSelf();
  }

  private void relaxResources(boolean releaseMediaPlayer) {
    Log.d(TAG, "relaxResources. releaseMediaPlayer=" + releaseMediaPlayer);
    // stop being a foreground service
    stopForeground(true);
    // stop and release the Media Player, if it's available
    if (releaseMediaPlayer && mediaPlayer != null) {
      mediaPlayer.reset();
      mediaPlayer.release();
      mediaPlayer = null;
    }
    // we can also release the Wifi lock, if we're holding it
    //We currently do not implement the wifi lock
    /*if (mWifiLock.isHeld()) {
      mWifiLock.release();
    }*/
  }
}
