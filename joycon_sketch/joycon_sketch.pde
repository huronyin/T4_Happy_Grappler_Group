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
/* end library imports *************************************************************************************************/  



/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);
/* end scheduler definition ********************************************************************************************/ 



/* device block definitions ********************************************************************************************/
Board             haplyBoard;
Device            widgetOne;
Mechanisms        pantograph;

byte              widgetOneID                         = 5;
int               CW                                  = 0;
int               CCW                                 = 1;
boolean           renderingForce                      = false;
/* end device block definition *****************************************************************************************/



/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;
/* end framerate definition ********************************************************************************************/ 



/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerCentimeter                 = 40.0;

/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           fEE                                = new PVector(0, 0); 

/* World boundaries in centimeters */
FWorld            world;
float             worldWidth                          = 25.0;  
float             worldHeight                         = 10.0; 

float             edgeTopLeftX                        = 0.0; 
float             edgeTopLeftY                        = 0.0; 
float             edgeBottomRightX                    = worldWidth; 
float             edgeBottomRightY                    = worldHeight;


/* Initialization of wall */
FBox              wall;
FBox              wall2;
FBox              wall3;
FBox              wall4;
FBox              door1;
FBox              door2;
FRevoluteJoint    joint1;
FCircle           ball;


/* Initialization of virtual tool */
HVirtualCoupling  s;
PImage            haplyAvatar;

/* end elements definition *********************************************************************************************/ 



/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once: */
  
  /* screen size definition */
  size(1000, 400);
  
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
  haplyBoard          = new Board(this, "COM3", 0);
  widgetOne           = new Device(widgetOneID, haplyBoard);
  pantograph          = new Pantograph();
  
  widgetOne.set_mechanism(pantograph);
  
  widgetOne.add_actuator(1, CCW, 2);
  widgetOne.add_actuator(2, CCW, 1);
 
  widgetOne.add_encoder(1, CCW, 168, 4880, 2);
  widgetOne.add_encoder(2, CCW, 12, 4880, 1);
  
  
  widgetOne.device_set_parameters();
  
  
  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world               = new FWorld();
  
  
  /* creation of wall */
  wall                   = new FBox(10.0, 0.5);
  wall.setPosition(edgeTopLeftX+worldWidth/2.0 - 1, edgeTopLeftY+2*worldHeight/3.0 - 0.3);
  wall.setStatic(true);
  wall.setFill(0, 0, 0);
  world.add(wall);

  /* creation of wall2 */
  wall2                   = new FBox(10.0, 0.5);
  wall2.setPosition(edgeTopLeftX+worldWidth/2.0 - 3, edgeTopLeftY+2*worldHeight/3.0 - 3);
  wall2.setStatic(true);
  wall2.setFill(0, 0, 0);
  world.add(wall2);
  
  /* creation of wall3 */
  wall3                   = new FBox(0.5, 7.0);
  wall3.setPosition(edgeTopLeftX+worldWidth/2.0 - 8, edgeTopLeftY+2*worldHeight/3.0 - 0.5);
  wall3.setStatic(true);
  wall3.setFill(0, 0, 0);
  world.add(wall3);  
  
  /* creation of wall4 */
  wall4                   = new FBox(0.5, 7.0);
  wall4.setPosition(edgeTopLeftX+worldWidth/2.0 + 4, edgeTopLeftY+2*worldHeight/3.0 - 0.5);
  wall4.setStatic(true);
  wall4.setFill(0, 0, 0);
  world.add(wall4);  
  
  ///* creation of door1 */
  //door1                   = new FBox(0.5, 6);
  //door1.setPosition(edgeTopLeftX+worldWidth/2.0 + 7, edgeTopLeftY+2*worldHeight/3.0 - 0.5);
  //door1.setStatic(false);
  //door1.setFill(0, 0, 0);
  //world.add(door1); 
  
  ///* creation of door2 */
  //door2                   = new FBox(0.5, 6);
  //door2.setPosition(edgeTopLeftX+worldWidth/2.0 + 5, edgeTopLeftY+2*worldHeight/3.0 - 1.5);
  //door2.setStatic(false);
  //door2.setFill(0, 0, 0);
  //world.add(door2); 
  
  //joint1 = new FRevoluteJoint(door1,door2);
  //world.add(joint1);
  
    
  /* creation of ball */
  ball                   = new FCircle(1.5);
  ball.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+2*worldHeight/3.0);
  ball.setStatic(false);
  ball.setFill(0, 0, 0);
  world.add(ball);
    
  /* Haptic Tool Initialization */
  s                   = new HVirtualCoupling((1)); 
  s.h_avatar.setDensity(4);  
  s.init(world, edgeTopLeftX+worldWidth/2+6.0, edgeTopLeftY+2*worldHeight/2.0); 
 
  
  /* If you are developing on a Mac users must update the path below 
   * from "../img/Haply_avatar.png" to "./img/Haply_avatar.png" 
   */
  haplyAvatar = loadImage("../img/smile.png"); 
  haplyAvatar.resize((int)(hAPI_Fisica.worldToScreen(1)), (int)(hAPI_Fisica.worldToScreen(1)));
  s.h_avatar.attachImage(haplyAvatar); 


  /* world conditions setup */
  world.setGravity((0.0), (1000.0)); //1000 cm/(s^2)
  world.setEdges((edgeTopLeftX), (edgeTopLeftY), (edgeBottomRightX), (edgeBottomRightY)); 
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
    
    if(haplyBoard.data_available()){
      /* GET END-EFFECTOR STATE (TASK SPACE) */
      widgetOne.device_read_data();
    
      angles.set(widgetOne.get_device_angles()); 
      posEE.set(widgetOne.get_device_position(angles.array()));
      posEE.set(posEE.copy().mult(200));  
    }
    
    s.setToolPosition(edgeTopLeftX+worldWidth/2-(posEE).x, edgeTopLeftY+(posEE).y-7); 
    
    
    s.updateCouplingForce();
    fEE.set(-s.getVirtualCouplingForceX(), s.getVirtualCouplingForceY());
    fEE.div(100000); //dynes to newtons
    
    torques.set(widgetOne.set_device_torques(fEE.array()));
    widgetOne.device_write_torques();
  
    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/



/* helper functions section, place helper functions here ***************************************************************/

/* end helper functions section ****************************************************************************************/
