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
boolean           rendering_force                     = false;


int               hardwareVersion                     = 3;
/* end device block definition *****************************************************************************************/



/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;
/* end framerate definition ********************************************************************************************/ 



/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerMeter                      = 6000.0;
float             xE=0;
float            yE=0;
/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           fEE                                 = new PVector(0, 0); 

/* World boundaries reference */
final int         worldPixelWidth                     = 1000;
final int         worldPixelHeight                    = 650;


/* Initialization of virtual tool */
PShape            eeAvatar;
ArrayList<PVector> positions = new ArrayList<PVector>();
int storePositions=50;

int travelledIndex=0;
PVector travelledPoint=new PVector(0,0);
float travelledDistance=0;

boolean gameCompleted = false;
/* end elements definition *********************************************************************************************/ 



/* setup section *******************************************************************************************************/
void setup(){
  /* screen size definition */
  size(1000, 650);
  
  /* device setup */
  haplyBoard          = new Board(this, "COM4", 0);
  widgetOne           = new Device(widgetOneID, haplyBoard);
  pantograph          = new Pantograph(hardwareVersion);
  
  widgetOne.set_mechanism(pantograph);
  
  
  if(hardwareVersion == 2){
    widgetOne.add_actuator(1, CCW, 2);
    widgetOne.add_actuator(2, CW, 1);
 
    widgetOne.add_encoder(1, CCW, 241, 10752, 2);
    widgetOne.add_encoder(2, CW, -61, 10752, 1);
  }
  else if(hardwareVersion == 3){
    widgetOne.add_actuator(1, CCW, 2);
    widgetOne.add_actuator(2, CCW, 1);
 
    widgetOne.add_encoder(1, CCW, 168, 4880, 2);
    widgetOne.add_encoder(2, CCW, 12, 4880, 1); 
  }
  
  
  widgetOne.device_set_parameters();
  

  /* setup framerate speed */
  frameRate(baseFrameRate);
  
  
  /* setup simulation thread to run at 1kHz */ 
  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 1, MILLISECONDS);

  generateSquarePath();
}
/* end setup section ***************************************************************************************************/



/* draw section ********************************************************************************************************/
void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  background(255); 
  update_end_effector();
  draw_path();
}
/* end draw section ****************************************************************************************************/


/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable{
  
  public void run(){
    /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
    
    rendering_force = true;
    
    if(haplyBoard.data_available()){
      /* GET END-EFFECTOR STATE (TASK SPACE) */
      widgetOne.device_read_data();
    
      angles.set(widgetOne.get_device_angles()); 
      posEE.set(widgetOne.get_device_position(angles.array()));
      posEE.set(device_to_graphics(posEE)); 
  
      xE = (pixelsPerMeter * posEE.x) + worldPixelWidth/2;
      yE = (pixelsPerMeter * (posEE.y-0.03));
    }

    pathTrackingMiniGameStateUpdate();

    // print("posEE: "+posEE.x+" "+posEE.y+"\n");
    // print("xE: "+xE+" yE: "+yE+"\n");
    // posEE.x left to right: -0.12 to 0.1
    // posEE.y up to down: 0 to 0.16

    fEE = calculateForceTowardPath();
    fEE.set(graphics_to_device(fEE));
    torques.set(widgetOne.set_device_torques(fEE.array()));
    widgetOne.device_write_torques();
    
  
    rendering_force = false;
  }
}
/* end simulation section **********************************************************************************************/


/* helper functions section, place helper functions here ***************************************************************/
void update_end_effector(){
  background(255);
  
  int eeWidth=20;
  PShape eeAvatar = createShape(ELLIPSE, xE, yE, eeWidth, eeWidth);
  eeAvatar.setFill(color(0));
  shape(eeAvatar);
}


ArrayList<PVector> squarePath = new ArrayList<PVector>();
float pathWidth = 20; // Adjust the width of the path as desired

void generateSquarePath() {
  float centerX = worldPixelWidth / 2;
  float centerY = worldPixelHeight / 2;
  float quadWidth = (centerX - pathWidth / 2)/2;
  float quadHeight = (centerY - pathWidth / 2)/2;

  squarePath.add(new PVector(quadWidth, quadHeight));
  squarePath.add(new PVector(quadWidth, centerY + quadHeight));
  squarePath.add(new PVector(centerX + quadWidth, centerY + quadHeight));
  squarePath.add(new PVector(centerX + quadWidth, quadHeight));
  travelledPoint.set(quadWidth, quadHeight);
}



void draw_path() {
  if (!gameCompleted) {
    draw_untravelled_path();
  }
  draw_travelled_path();
}

void draw_untravelled_path() {
  noFill();
  stroke(0);
  strokeWeight(pathWidth);
  
  for (int i = travelledIndex; i < travelledIndex+1; i++) {
    PVector start = squarePath.get(i);
    PVector end = squarePath.get((i + 1) % squarePath.size());
    beginShape();
    vertex(start.x, start.y);
    vertex(end.x, end.y);
    endShape(CLOSE);
  }

}

void draw_travelled_path() {
  noFill();
  stroke(0,200,200);
  strokeWeight(pathWidth);
  
  if (travelledIndex >0) {
    for (int i = 0; i < travelledIndex; i++) {
      PVector start = squarePath.get(i);
      PVector end = squarePath.get((i + 1) % squarePath.size());
      beginShape();
      vertex(start.x, start.y);
      vertex(end.x, end.y);
      endShape(CLOSE);
    }
  }
  
  if (travelledIndex >= squarePath.size()) {
    // for this player, it's already finished
    return ;
  }

  PVector start=squarePath.get(travelledIndex);
  PVector end=travelledPoint;
  beginShape();
  vertex(start.x, start.y);
  vertex(end.x, end.y);
  endShape(CLOSE);
  stroke(0);
}


PVector lastLoopForceFeedback = new PVector(0, 0);

PVector calculateForceTowardPath() {
  if (gameCompleted) {
    return new PVector(0, 0);
  }

  PVector forceDirection = PVector.sub(travelledPoint, new PVector(xE, yE));
  float distance = forceDirection.mag();
  PVector forceFeedback = new PVector(0, 0);

  print("distance: "+distance+"\n");
  // no force feedback if it's too close to the path, partly to reduce oscillation
  if (distance > 25) {
    forceDirection.normalize();
    print("forceDirectionNormalized: "+forceDirection.x+" "+forceDirection.y+"\n");
    forceFeedback=forceDirection.normalize().mult(0.03*distance);
  }
  print("forceFeedback: "+forceFeedback.x+" "+forceFeedback.y+"\n");

  // A bug I can't figure out
  // PVector temp=forceFeedback;
  // forceFeedback=forceFeedback.mult(0.3);
  // forceFeedback.add(lastLoopForceFeedback.mult(0.7));
  // lastLoopForceFeedback = temp;
  // print("forceFeedbackAfterSmooth: "+forceFeedback.x+" "+forceFeedback.y+"\n");
  
  return forceFeedback;
}


void pathTrackingMiniGameStateUpdate() {
  if (gameCompleted) {
    return ;
  }

  int i=travelledIndex;
  PVector start = squarePath.get(i);
  PVector end = squarePath.get((i + 1) % squarePath.size());
  PVector closest = getClosestPointOnLine(new PVector(xE, yE), start, end);
  
  float distanceEEandClosest = PVector.dist(new PVector(xE, yE), closest);
  
  // too far from the path
  if (distanceEEandClosest > 40){
    return ;
  }

  float nowTravelledDistance = PVector.dist(start, closest);

  // it's jumping, not continuous movement along the path
  if (nowTravelledDistance - travelledDistance >50){
    return ;
  }

  //  update the travelled distance and the travelled point
  if (nowTravelledDistance > travelledDistance) {
    travelledDistance = nowTravelledDistance;
    travelledPoint = closest;
  }

  float fullDistance = PVector.dist(start, end);
  // one path is completed
  if (nowTravelledDistance > fullDistance*0.99) {
    travelledDistance = 0;
    travelledIndex = travelledIndex + 1;
    
    if (travelledIndex == squarePath.size()) {
      // game completed
      gameCompleted = true;
      return ;
    }

    travelledPoint = squarePath.get(travelledIndex);
  }

}





PVector getClosestPointOnLine(PVector point, PVector start, PVector end) {
  PVector lineVector = PVector.sub(end, start);
  PVector pointVector = PVector.sub(point, start);
  float projectionLength = pointVector.dot(lineVector) / lineVector.magSq();
  projectionLength = constrain(projectionLength, 0, 1);
  return PVector.add(start, PVector.mult(lineVector, projectionLength));
}


PVector device_to_graphics(PVector deviceFrame){
  return deviceFrame.set(-deviceFrame.x, deviceFrame.y);
}

PVector graphics_to_device(PVector graphicsFrame){
  return graphicsFrame.set(-graphicsFrame.x, graphicsFrame.y);
}

/* end helper functions section ****************************************************************************************/
