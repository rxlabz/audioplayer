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
import android.graphics.Bitmap;
import android.media.MediaDescription;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Build;
import android.content.pm.PackageManager;

public class OreoMediaNotificationManager extends MediaNotificationManager {

    private static final int NOTIFICATION_ID = 412;
    private static final int REQUEST_CODE = 100;
    private static final String channelID ="com.bz.rxla.notificationChannel";


    private final AudioplayerPlugin mService;
    private Context mContext;
    private final NotificationManager mNotificationManager;

    private final Notification.Action mPlayAction;
    private final Notification.Action mPauseAction;
    private final Notification.Action mNextAction;
    private final Notification.Action mPrevAction;

    private boolean mStarted;
    private boolean cancelWhenNotPlaying;
    public OreoMediaNotificationManager(AudioplayerPlugin service, Context context, boolean onlyShowWhenPlaying) {
        super(service, context, onlyShowWhenPlaying);
        this.cancelWhenNotPlaying = onlyShowWhenPlaying;
        mService = service;
        mContext=context;
        String pkg = context.getPackageName();
        PendingIntent playIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(Strings.ACTION_PLAY).setPackage(pkg), PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent pauseIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(Strings.ACTION_PAUSE).setPackage(pkg), PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent nextIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(Strings.ACTION_NEXT).setPackage(pkg), PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent prevIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(Strings.ACTION_PREV).setPackage(pkg), PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_CANCEL_CURRENT);

        mPlayAction = new Notification.Action(R.drawable.ic_play_arrow_white_24dp,
                context.getString(R.string.label_play), playIntent);
        mPauseAction = new Notification.Action(R.drawable.ic_pause_white_24dp,
                context.getString(R.string.label_pause), pauseIntent);
        mNextAction = new Notification.Action(R.drawable.ic_skip_next_white_24dp,
                context.getString(R.string.label_next), nextIntent);
        mPrevAction = new Notification.Action(R.drawable.ic_skip_previous_white_24dp,
                context.getString(R.string.label_previous), prevIntent);



        mNotificationManager = (NotificationManager) context
                .getSystemService(Context.NOTIFICATION_SERVICE);

        // Cancel all notifications to handle the case where the Service was killed and
        // restarted by the system.
        //mNotificationManager.cancelAll();

        if(Build.VERSION.SDK_INT > 25){
            // The user-visible name of the channel.
            CharSequence name = "CHannelName";

// The user-visible description of the channel.
            String description = "decriptionsOf the channel";

            int importance = NotificationManager.IMPORTANCE_LOW;

            NotificationChannel mChannel = new NotificationChannel(Strings.channelID, name,importance);

// Configure the notification channel.
            mChannel.setDescription(description);

            mChannel.enableLights(true);
// Sets the notification light color for notifications posted to this
// channel, if the device supports this feature.
            mChannel.setLightColor(Color.RED);

            mChannel.enableVibration(true);
            mChannel.setVibrationPattern(new long[]{100, 200, 300, 400, 500, 400, 300, 200, 400});

            if(Build.VERSION.SDK_INT > 26){
                mChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            }

            mNotificationManager.createNotificationChannel(mChannel);
        }
    }


    public void update(MediaMetadata metadata, PlaybackState state, MediaSession.Token token) {
        if (metadata == null) {
            return;
        }
        boolean isPlaying = state.getState() == PlaybackState.STATE_PLAYING;
        Notification.Builder notificationBuilder = new Notification.Builder(mContext);
        MediaDescription description = metadata.getDescription();
        Bitmap albumArt = metadata.getBitmap(MediaMetadata.METADATA_KEY_ART);

        notificationBuilder
                .setStyle(new Notification.MediaStyle()
                        .setMediaSession(token)
                        .setShowActionsInCompactView(0, 1, 2))
                .setColor(mContext.getResources().getColor(R.color.notification_bg))
                .setChannelId(Strings.channelID)
                .setSmallIcon(R.drawable.ic_notification)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setContentIntent(createContentIntent())
                .setContentTitle(description.getTitle())
                .setContentText(description.getSubtitle())
                .setOngoing(isPlaying)
                .setWhen(isPlaying ? System.currentTimeMillis() - state.getPosition() : 0)
                .setShowWhen(!this.cancelWhenNotPlaying || isPlaying)
                .setUsesChronometer(isPlaying);

        // If skip to next action is enabled
        if ((state.getActions() & PlaybackState.ACTION_SKIP_TO_PREVIOUS) != 0) {
            notificationBuilder.addAction(mPrevAction);
        }

        notificationBuilder.addAction(isPlaying ? mPauseAction : mPlayAction);

        // If skip to prev action is enabled
        if ((state.getActions() & PlaybackState.ACTION_SKIP_TO_NEXT) != 0) {
            notificationBuilder.addAction(mNextAction);
        }

        if(albumArt != null){
            notificationBuilder.setLargeIcon(albumArt);
        }

        Notification notification = notificationBuilder.build();

        if (!isPlaying && this.cancelWhenNotPlaying) {
            mNotificationManager.cancel(NOTIFICATION_ID);
            mStarted = false;
        }else{
            mNotificationManager.notify(NOTIFICATION_ID, notification);
            mStarted = true;
        }
    }

    private PendingIntent createContentIntent() {
        String packageName = mContext.getPackageName();
        PackageManager pm = mContext.getPackageManager();
        Intent launchIntent = pm.getLaunchIntentForPackage(packageName);
        return PendingIntent.getActivity(mContext, REQUEST_CODE, launchIntent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_CANCEL_CURRENT);
    }
}
