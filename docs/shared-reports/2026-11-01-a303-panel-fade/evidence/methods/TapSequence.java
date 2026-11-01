import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.MotionEvent;
import java.lang.reflect.Method;

// Shell-only test input helper. No APK, account access or app-data mutation.
public class TapSequence {
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
    for(int i=0;i<args.length;i+=3){
      float x=Float.parseFloat(args[i]),y=Float.parseFloat(args[i+1]);
      down=SystemClock.uptimeMillis();
      send(MotionEvent.ACTION_DOWN,new float[]{x,y});
      SystemClock.sleep(16);send(MotionEvent.ACTION_UP,new float[]{x,y});
      System.out.println("tap "+x+","+y+" at "+SystemClock.uptimeMillis());
      SystemClock.sleep(Integer.parseInt(args[i+2]));
    }
  }
}
