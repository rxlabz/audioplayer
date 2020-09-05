package bz.rxla.audioplayer;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.drawable.Icon;
import android.media.MediaDescription;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.support.v4.media.session.MediaSessionCompat;
import android.util.Log;

import androidx.core.app.NotificationCompat;

/**
 * Keeps track of a notification and updates it automatically for a given
 * MediaSession. This is required so that the music service
 * don't get killed during playback.
 */
public class MediaNotificationManager extends BroadcastReceiver {
    private static final int NOTIFICATION_ID = 412;
    private static final int REQUEST_CODE = 100;

    private static final String ACTION_PAUSE = "com.example.android.musicplayercodelab.pause";
    private static final String ACTION_PLAY = "com.example.android.musicplayercodelab.play";
    private static final String ACTION_NEXT = "com.example.android.musicplayercodelab.next";
    private static final String ACTION_PREV = "com.example.android.musicplayercodelab.prev";

    private final AudioplayerPlugin mService;
    private Context mContext;
    private final NotificationManager mNotificationManager;

    private final NotificationCompat.Action mPlayAction;
    private final NotificationCompat.Action mPauseAction;
    private final NotificationCompat.Action mNextAction;
    private final NotificationCompat.Action mPrevAction;

    private boolean mStarted;
    private NotificationManager nManager;
    private boolean cancelWhenNotPlaying;

    public MediaNotificationManager(AudioplayerPlugin service, Context context, boolean cancelWhenNotPlaying) {
        mService = service;
        mContext = context;
        this.cancelWhenNotPlaying = cancelWhenNotPlaying;
        String pkg = context.getPackageName();
        PendingIntent playIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_PLAY).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent pauseIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_PAUSE).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent nextIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_NEXT).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);
        PendingIntent prevIntent = PendingIntent.getBroadcast(context, REQUEST_CODE,
                new Intent(ACTION_PREV).setPackage(pkg), PendingIntent.FLAG_CANCEL_CURRENT);

        mPlayAction = new NotificationCompat.Action(R.drawable.ic_play_arrow_white_24dp,
                context.getString(R.string.label_play), playIntent);
        mPauseAction = new NotificationCompat.Action(R.drawable.ic_pause_white_24dp,
                context.getString(R.string.label_pause), pauseIntent);
        mNextAction = new NotificationCompat.Action(R.drawable.ic_skip_next_white_24dp,
                context.getString(R.string.label_next), nextIntent);
        mPrevAction = new NotificationCompat.Action(R.drawable.ic_skip_previous_white_24dp,
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
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        switch (action) {
            case ACTION_PAUSE:
                mService.pause();
                mService.UpdateNotificationManager();
                break;
            case ACTION_PLAY:
                mService.playCurrentOnly();
                mService.UpdateNotificationManager();
                break;
            case ACTION_NEXT:
                mService.onSkipToNext();
                mService.UpdateNotificationManager();
                break;
            case ACTION_PREV:
                mService.onSkipToPrevious();
                mService.UpdateNotificationManager();
                break;
        }
    }

    public void hideNotification(){
        mNotificationManager.cancel(2);
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
        NotificationCompat.Builder notificationBuilder = (NotificationCompat.Builder) new NotificationCompat.Builder(mContext);
        MediaDescription description = metadata.getDescription();

        notificationBuilder
                .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
                        .setMediaSession(MediaSessionCompat.Token.fromToken(token))
                        .setShowActionsInCompactView(0, 1, 2))
                .setColor(mContext.getResources().getColor(R.color.notification_bg))
                .setSmallIcon(R.drawable.ic_notification)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(createContentIntent())
                .setContentTitle(description.getTitle())
                .setContentText(description.getSubtitle())
                .setOngoing(isPlaying)
                .setWhen(isPlaying ? System.currentTimeMillis() - state.getPosition() : 0)
                .setShowWhen(!this.cancelWhenNotPlaying || isPlaying)
                .setUsesChronometer(isPlaying);

        notificationBuilder.addAction(mPrevAction);
        notificationBuilder.addAction(isPlaying ? mPauseAction : mPlayAction);

        notificationBuilder.addAction(mNextAction);
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