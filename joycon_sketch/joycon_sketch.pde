/**
 **********************************************************************************************************************
 * @file       sketch_4_Wall_Physics.pde
 * @author     Steve Ding, Colin Gallacher
 * @version    V4.1.0
 * @date       08-January-2021
 * @brief      wall haptic example using 2D physics engine 
 **********************************************************************************************************************
 * @attention
 *
 *
 **********************************************************************************************************************
 */



/* library imports *****************************************************************************************************/ 
import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
import java.util.*;
import java.lang.*;
/* end library imports *************************************************************************************************/  



/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);
/* end scheduler definition ********************************************************************************************/ 

boolean           renderingForce                      = false;

/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;
/* end framerate definition ********************************************************************************************/ 



/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerCentimeter                 = 40.0;

/* World boundaries in centimeters */
FWorld            world;
float             worldWidth                          = 25.0;  
float             worldHeight                         = 25.0; 
float             edgeTopLeftX                        = 0.0; 
float             edgeTopLeftY                        = 0.0; 
float             edgeBottomRightX                    = worldWidth; 
float             edgeBottomRightY                    = worldHeight;


/* Initialization of walls */
FBox              wall;

/* Initialization of avatars */
HaplyAvatar       avatar1;
HaplyAvatar       avatar2;

/* end elements definition *********************************************************************************************/ 



/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once: */
  
  /* screen size definition */
  size(1000, 1000);
  
  /* device setup */
  
  /**  
   * The board declaration needs to be changed depending on which USB serial port the Haply board is connected.
   * In the base example, a connection is setup to the first detected serial device, this parameter can be changed
   * to explicitly state the serial port will look like the following for different OS:
   *
   *      windows:      haplyBoard = new Board(this, "COM10", 0);
   *      linux:        haplyBoard = new Board(this, "/dev/ttyUSB0", 0);
   *      mac:          haplyBoard = new Board(this, "/dev/cu.usbmodem1411", 0);
   */ 
  
  
  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world               = new FWorld();
  
  /* Haply avatar initialization */
  avatar1 = new HaplyAvatar("COM5", world);
  avatar2 = new HaplyAvatar("COM6", world);

  avatar1.setup(this);
  avatar2.setup(this);
  
  /* creation of wall */
  wall                   = new FBox(10.0, 0.5);
  wall.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+2*worldHeight/3.0);
  wall.setStatic(true);
  wall.setFill(0, 0, 0);
  //wall.setRestitution(1.0f);
  world.add(wall);
 
  /* world conditions setup */
  world.setGravity((0.0), (0.0)); //1000 cm/(s^2)
  world.setEdges((edgeTopLeftX), (edgeTopLeftY), (edgeBottomRightX), (edgeBottomRightY),color(255,0,0)); 
  world.setEdgesRestitution(.4);
  world.setEdgesFriction(0.5);
  
  world.draw();
  
  
  /* setup framerate speed */
  frameRate(baseFrameRate);
  

  /* setup simulation thread to run at 1kHz */ 
  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 1, MILLISECONDS);
}
/* end setup section ***************************************************************************************************/



/* draw section ********************************************************************************************************/
void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  if(renderingForce == false){
    background(255);
    world.draw();
  }
}
/* end draw section ****************************************************************************************************/



/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable{
  
  public void run(){
    /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
    renderingForce = true;
    
    avatar1.run();
    avatar2.run();

    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/



/* helper functions section, place helper functions here ***************************************************************/

public class HaplyAvatar{
    /* device block definitions ********************************************************************************************/
    Board             haplyBoard;
    Device            widget;
    Mechanisms        pantograph;

    byte              widgetID                            = 5;
    int               CW                                  = 0;
    int               CCW                                 = 1;
    boolean           renderingForce                      = false;
    /* end device block definition *****************************************************************************************/

    /* joint space */
    PVector           angles                              = new PVector(0, 0);
    PVector           torques                             = new PVector(0, 0);

    /* task space */
    PVector           posEE                               = new PVector(0, 0);
    PVector           fEE                                = new PVector(0, 0); 


    /* joycon spring parameters  */
    float             kSpring                             = 110;
    PVector           deltaXSpring                        = new PVector(0, 0);
    PVector           fSpring                             = new PVector(0, 0);
    PVector           xSpring                             = new PVector(0, 0.1);

    /* Initialization of fisica stuff */
    FWorld            world;
    FCircle           sh_avatar;

    /* Virtual avatar parameters */
    float             movementSpeed = 1.0e2;
    float             reactionMult = 2;

    /* initializing virtual avatar variables */
    PImage            haplyAvatar;
    ArrayList<FContact>         contactList                          = null;

    /* USB port */
    String            port = "";

    public HaplyAvatar(String port, FWorld world){
        this.port = port;
        this.world = world;

    }

    public void setup(PApplet app){
        haplyBoard          = new Board(app, port, 0);
        widget              = new Device(widgetID, haplyBoard);
        pantograph          = new Pantograph();
        
        widget.set_mechanism(pantograph);
        widget.add_actuator(1, CCW, 2);
        widget.add_actuator(2, CCW, 1);
        widget.add_encoder(1, CCW, 168, 4880, 2);
        widget.add_encoder(2, CCW, 12, 4880, 1);
        widget.device_set_parameters();

        sh_avatar = new FCircle(1.8);
        sh_avatar.setDensity(4);  
        sh_avatar.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+2*worldHeight/7.0); 
        sh_avatar.setHaptic(true, 1000, 1);
        world.add(sh_avatar);

        haplyAvatar = loadImage("../img/smile.png"); 
        haplyAvatar.resize((int)(hAPI_Fisica.worldToScreen(1.8)), (int)(hAPI_Fisica.worldToScreen(1.8)));
        sh_avatar.attachImage(haplyAvatar); 
    }

    public void run(){
        /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
        
        if(haplyBoard.data_available()){
            /* GET END-EFFECTOR STATE (TASK SPACE) */
            widget.device_read_data();
            
            angles.set(widget.get_device_angles()); 
            posEE.set(widget.get_device_position(angles.array()));
        }
        
        // calculate deltaXSpring
        deltaXSpring = posEE.sub(xSpring);
        
        // move avatar based on deltaXSpring
        sh_avatar.setVelocity(-deltaXSpring.x * movementSpeed, deltaXSpring.y * movementSpeed);
            
        // calculate restoring joycon force
        fSpring.set(0, 0);
        fSpring = fSpring.add(deltaXSpring.mult(-kSpring));
        fEE = (fSpring.copy());
        
        // calculate collision reaction forces
        contactList = sh_avatar.getContacts();
        for(int i=0;i<contactList.size();i++)
        {
        fEE.add(contactList.get(i).getVelocityX() * reactionMult, -contactList.get(i).getVelocityY() * reactionMult);
        }
        
        torques.set(widget.set_device_torques(fEE.array()));
        widget.device_write_torques();
    }
}

/* end helper functions section ****************************************************************************************/
