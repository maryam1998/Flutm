package com.linglearn.app.overlay;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.projection.MediaProjectionConfig;
import android.media.projection.MediaProjectionManager;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

public class ProjectionActivity extends Activity {

    private static final String TAG = "ProjectionActivity";
    private static final int REQ_AUDIO = 1;
    private static final int REQ_PROJECTION = 2;
    /** true = درخواست از «حباب ذره‌بین» است (نه ترجمه‌ی زنده): میکروفون لازم نیست، نتیجه به MagnifierService می‌رود. */
    public static final String EXTRA_MAGNIFIER = "magnifier";
    /** true = حتماً پنجره‌ی اندروید را نشان بده (مجوزِ مشترکِ قبلی توسطِ سیستم پذیرفته نشد). */
    public static final String EXTRA_FORCE = "force";
    private boolean forMagnifier = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (savedInstanceState != null) return;
        forMagnifier = getIntent().getBooleanExtra(EXTRA_MAGNIFIER, false);
        if (!forMagnifier && checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, REQ_AUDIO);
        } else {
            proceed();
        }
    }

    /** مجوزِ ضبطِ صفحه/صدا بینِ ذره‌بین و ترجمه‌ی زنده مشترک است؛ اگر قبلاً داده شده، پنجره‌ی اندروید دوباره نمی‌آید. */
    private void proceed() {
        if (!getIntent().getBooleanExtra(EXTRA_FORCE, false) && ProjectionHolder.canReuse()) dispatch(RESULT_OK, null);
        else launchProjection();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_AUDIO) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                proceed();
            } else {
                deny();
            }
        }
    }

    private void launchProjection() {
        MediaProjectionManager mpm = (MediaProjectionManager) getSystemService(MEDIA_PROJECTION_SERVICE);
        if (mpm == null) {
            Log.e(TAG, "MediaProjectionManager is null");
            deny();
            return;
        }

        Intent intent;
        if (Build.VERSION.SDK_INT >= 34) {
            // Android 14+: فقط Entire Screen (نه تک‌اپ) → اپ‌های دیگه قفل نمی‌شن
            intent = mpm.createScreenCaptureIntent(
                    MediaProjectionConfig.createConfigForDefaultDisplay()
            );
        } else {
            intent = mpm.createScreenCaptureIntent();
        }

        try {
            startActivityForResult(intent, REQ_PROJECTION);
        } catch (Exception e) {
            Log.e(TAG, "cannot launch projection intent", e);
            deny();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_PROJECTION) return;
        forMagnifier = getIntent().getBooleanExtra(EXTRA_MAGNIFIER, false);
        if (resultCode == RESULT_OK && data != null) {
            dispatch(resultCode, data);
        } else {
            deny();
        }
    }

    /** data == null ⇒ از مجوزِ مشترکِ ProjectionHolder استفاده کن (بدونِ پنجره‌ی اندروید). */
    private void dispatch(int resultCode, Intent data) {
        boolean reuse = data == null;
        if (forMagnifier) {
            Intent mi = new Intent(this, MagnifierService.class).setAction(MagnifierService.ACTION_START);
            if (reuse) mi.putExtra(MagnifierService.EXTRA_REUSE, true);
            else mi.putExtra(MagnifierService.EXTRA_RESULT_CODE, resultCode).putExtra(MagnifierService.EXTRA_DATA, data);
            startForegroundService(mi);
        } else {
            Intent i = new Intent(this, BubbleService.class).setAction(BubbleService.ACTION_PROJECTION_RESULT);
            if (reuse) i.putExtra(BubbleService.EXTRA_REUSE, true);
            else i.putExtra(BubbleService.EXTRA_RESULT_CODE, resultCode).putExtra(BubbleService.EXTRA_DATA, data);
            startForegroundService(i);
        }
        finish();
    }

    private void deny() {
        if (forMagnifier) { finish(); return; }
        startService(new Intent(this, BubbleService.class).setAction(BubbleService.ACTION_PROJECTION_DENIED));
        finish();
    }
}
