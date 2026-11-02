import android.content.Context;
import android.graphics.*;
import android.graphics.drawable.*;
import android.os.Looper;
import java.io.FileOutputStream;
// Read-only rendering of the installed application's actual adaptive-icon layers.
public class IconMasks {
 public static void main(String[] args)throws Exception {
  Looper.prepareMainLooper();
  Class<?> at=Class.forName("android.app.ActivityThread");
  Object thread=at.getMethod("systemMain").invoke(null);
  Context context=(Context)at.getMethod("getSystemContext").invoke(thread);
  Drawable source=context.getPackageManager().getApplicationIcon("com.roxhistory.demo");
  Bitmap b=Bitmap.createBitmap(900,480,Bitmap.Config.ARGB_8888);Canvas c=new Canvas(b);c.drawColor(Color.rgb(30,34,40));
  Paint p=new Paint(3);p.setColor(Color.WHITE);p.setTextSize(24);
  String[] labels={"System mask","Round rectangle","Small 48px"};
  for(int i=0;i<3;i++){
   int size=i==2?48:240;int x=35+i*290,y=90;
   c.save();c.translate(x,y);source.setBounds(0,0,size,size);
   if(i<2 && source instanceof AdaptiveIconDrawable){
    Path mask=new Path();if(i==0)mask.addOval(new RectF(0,0,size,size),Path.Direction.CW);else mask.addRoundRect(new RectF(0,0,size,size),size*.23f,size*.23f,Path.Direction.CW);c.clipPath(mask);
    // draw once offscreen so the framework computes layer bounds, then reuse them.
    Bitmap temp=Bitmap.createBitmap(size,size,Bitmap.Config.ARGB_8888);source.draw(new Canvas(temp));
    AdaptiveIconDrawable d=(AdaptiveIconDrawable)source;d.getBackground().draw(c);d.getForeground().draw(c);
   }else source.draw(c);
   c.restore();
  }
  try(FileOutputStream f=new FileOutputStream("/data/local/tmp/rox-icon-masks.png")){b.compress(Bitmap.CompressFormat.PNG,100,f);}
  System.out.println("Rendered installed "+source.getClass().getName());
 }
}
