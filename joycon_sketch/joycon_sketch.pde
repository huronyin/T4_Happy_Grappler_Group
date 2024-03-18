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
float             worldHeight                         = 10.0; 
float             edgeTopLeftX                        = 0.0; 
float             edgeTopLeftY                        = 0.0; 
float             edgeBottomRightX                    = worldWidth; 
float             edgeBottomRightY                    = worldHeight;


/* Initialization of walls */
FBox              wall;
FBox              wall2;
FBox              wall3;
FBox              wall4;
FBox              door1;
FBox              door2;
FRevoluteJoint    joint1;
FCircle           ball;

/* Initialization of avatars */
HaplyAvatar       avatar1;
HaplyAvatar       avatar2;

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
  
  
  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world               = new FWorld();
  
  /* Haply avatar initialization */
  avatar1 = new HaplyAvatar("COM5", world);
  avatar2 = new HaplyAvatar("COM6", world);

  avatar1.setup();
  avatar2.setup();
  
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
 
  /* world conditions setup */
  world.setGravity((0.0), (0.0)); //1000 cm/(s^2)
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
    
    avatar1.run();
    avatar2.run();

    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/



/* helper functions section, place helper functions here ***************************************************************/

/* end helper functions section ****************************************************************************************/
