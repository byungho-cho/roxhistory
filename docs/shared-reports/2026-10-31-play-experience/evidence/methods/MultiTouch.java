import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.MotionEvent;
import java.lang.reflect.Method;

// Shell-only test input helper. No APK, account access or app-data mutation.
public class MultiTouch {
  static Object manager;
  static Method inject;
  static long down;
  static void send(int action, float[] xy) throws Exception {
    int count=xy.length/2;
    MotionEvent.PointerProperties[] props=new MotionEvent.PointerProperties[count];
    MotionEvent.PointerCoords[] coords=new MotionEvent.PointerCoords[count];
    for(int i=0;i<count;i++){
      props[i]=new MotionEvent.PointerProperties();props[i].id=i;props[i].toolType=MotionEvent.TOOL_TYPE_FINGER;
      coords[i]=new MotionEvent.PointerCoords();coords[i].x=xy[i*2];coords[i].y=xy[i*2+1];coords[i].pressure=1;coords[i].size=.08f;
    }
    MotionEvent event=MotionEvent.obtain(down,SystemClock.uptimeMillis(),action,count,props,coords,0,0,1,1,0,0,InputDevice.SOURCE_TOUCHSCREEN,0);
    if(!((Boolean)inject.invoke(manager,event,2))) throw new IllegalStateException("Input rejected");
    event.recycle();
  }
  public static void main(String[] args) throws Exception {
    Class<?> type=Class.forName("android.hardware.input.InputManagerGlobal");
    manager=type.getMethod("getInstance").invoke(null);
    inject=type.getMethod("injectInputEvent",InputEvent.class,int.class);
    float[] start=new float[4],end=new float[4];
    for(int i=0;i<4;i++){start[i]=Float.parseFloat(args[i]);end[i]=Float.parseFloat(args[i+4]);}
    int millis=Integer.parseInt(args[8]);int steps=Math.max(2,millis/20);
    down=SystemClock.uptimeMillis();send(MotionEvent.ACTION_DOWN,new float[]{start[0],start[1]});
    SystemClock.sleep(40);send(MotionEvent.ACTION_POINTER_DOWN|(1<<MotionEvent.ACTION_POINTER_INDEX_SHIFT),start);
    for(int j=1;j<=steps;j++){
      float[] xy=new float[4];for(int i=0;i<4;i++)xy[i]=start[i]+(end[i]-start[i])*j/steps;
      SystemClock.sleep(20);send(MotionEvent.ACTION_MOVE,xy);
    }
    send(MotionEvent.ACTION_POINTER_UP|(1<<MotionEvent.ACTION_POINTER_INDEX_SHIFT),end);
    SystemClock.sleep(40);send(MotionEvent.ACTION_UP,new float[]{end[0],end[1]});
    System.out.println("Injected two-pointer Android MotionEvents: "+steps+" move samples");
  }
}
