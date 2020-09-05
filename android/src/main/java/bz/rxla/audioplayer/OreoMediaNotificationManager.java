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
import android.media.MediaDescription;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Build;

public class OreoMediaNotificationManager extends MediaNotificationManager {

    private static final int NOTIFICATION_ID = 412;
    private static final int REQUEST_CODE = 100;
    private static final String channelID ="com.bz.rxla.notificationChannel";
    private static final String ACTION_PAUSE = "com.example.android.musicplayercodelab.pause";
    private static final String ACTION_PLAY = "com.example.android.musicplayercodelab.play";
    private static final String ACTION_NEXT = "com.example.android.musicplayercodelab.next";
    private static final String ACTION_PREV = "com.example.android.musicplayercodelab.prev";

    private final AudioplayerPlugin mService;
    private Context mContext;
    private final NotificationManager mNotificationManager;

    private final Notification.Action mPlayAction;
    private final Notification.Action mPauseAction;
    private final Notification.Action mNextAction;
    private final Notification.Action mPrevAction;

    private boolean mStarted;
    private NotificationManager nManager;
    private boolean cancelWhenNotPlaying;
    public OreoMediaNotificationManager(AudioplayerPlugin service, Context context, boolean onlyShowWhenPlaying) {
        super(service, context, onlyShowWhenPlaying);
        this.cancelWhenNotPlaying = onlyShowWhenPlaying;
        mService = service;
        mContext=context;
        String pkg = context.getPackageName();
        PendingIntent playIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_PLAY).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent pauseIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_PAUSE).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent nextIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_NEXT).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent prevIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_PREV).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);

        mPlayAction = new Notification.Action(R.drawable.ic_play_arrow_white_24dp,
                context.getString(R.string.label_play), playIntent);
        mPauseAction = new Notification.Action(R.drawable.ic_pause_white_24dp,
                context.getString(R.string.label_pause), pauseIntent);
        mNextAction = new Notification.Action(R.drawable.ic_skip_next_white_24dp,
                context.getString(R.string.label_next), nextIntent);
        mPrevAction = new Notification.Action(R.drawable.ic_skip_previous_white_24dp,
                context.getString(R.string.label_previous), prevIntent);

        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_NEXT);
        filter.addAction(ACTION_PAUSE);
        filter.addAction(ACTION_PLAY);
        filter.addAction(ACTION_PREV);

        context.registerReceiver(this, filter);


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

            NotificationChannel mChannel = new NotificationChannel(channelID, name,importance);

// Configure the notification channel.
            mChannel.setDescription(description);

            mChannel.enableLights(true);
// Sets the notification light color for notifications posted to this
// channel, if the device supports this feature.
            mChannel.setLightColor(Color.RED);

            mChannel.enableVibration(true);
            mChannel.setVibrationPattern(new long[]{100, 200, 300, 400, 500, 400, 300, 200, 400});

            mNotificationManager.createNotificationChannel(mChannel);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        switch (action) {
            case ACTION_PAUSE:
                mService.pause();
                break;
            case ACTION_PLAY:
                mService.playCurrentOnly();
                break;
            case ACTION_NEXT:
                mService.onSkipToNext();
                break;
            case ACTION_PREV:
                mService.onSkipToPrevious();
                break;
        }
    }

    public void update(MediaMetadata metadata, PlaybackState state, MediaSession.Token token) {
        if (state == null || state.getState() == PlaybackState.STATE_STOPPED ||
                state.getState() == PlaybackState.STATE_NONE) {
            //mService.stopForeground(true);
            try {
                mContext.unregisterReceiver(this);
            } catch (IllegalArgumentException ex) {
                // ignore receiver not registered
            }
            //mService.stopSelf();
            return;
        }
        if (metadata == null) {
            return;
        }
        boolean isPlaying = state.getState() == PlaybackState.STATE_PLAYING;
        Notification.Builder notificationBuilder = new Notification.Builder(mContext);
        MediaDescription description = metadata.getDescription();

        notificationBuilder
                .setStyle(new Notification.MediaStyle()
                        .setMediaSession(token)
                        .setShowActionsInCompactView(0, 1, 2))
                .setColor(mContext.getResources().getColor(R.color.notification_bg))
                .setChannelId(channelID)
                .setSmallIcon(R.drawable.ic_notification)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setContentIntent(createContentIntent())
                .setContentTitle(description.getTitle())
                .setContentText(description.getSubtitle())
                //.setLargeIcon(Icon.createWithResource(mService.getApplicationContext(), R.drawable.ic_notification))
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

        Notification notification = notificationBuilder.build();

        if (!isPlaying && this.cancelWhenNotPlaying) {
            mNotificationManager.cancel(2);
            mStarted = false;
        }else{
            mNotificationManager.notify(2, notification);
            mStarted = true;
        }
    }

    private PendingIntent createContentIntent() {
        Intent openUI = new Intent(mContext, AudioplayerPlugin.class);
        openUI.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(mContext, REQUEST_CODE, openUI,
                PendingIntent.FLAG_CANCEL_CURRENT);
    }
}
