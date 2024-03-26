/* library imports *****************************************************************************************************/ 
import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
import java.util.Collections;
/* end library imports *************************************************************************************************/  


/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);
/* end scheduler definition ********************************************************************************************/ 



/* device block definitions ********************************************************************************************/
Board             haplyBoard;
Board             haplyBoard2;

Device            widgetOne;
Device            widgetOne2;

Mechanisms        pantograph;
Mechanisms        pantograph2;

byte              widgetOneID                         = 5;
int               CW                                  = 0;
int               CCW                                 = 1;
boolean           rendering_force                     = false;


int               hardwareVersion                     = 2;
/* end device block definition *****************************************************************************************/



/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;
/* end framerate definition ********************************************************************************************/ 



/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerMeter                      = 6000.0;
float             xE=0;
float             yE=0;
float             xE2=0;
float             yE2=0;

/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           fEE                                 = new PVector(0, 0); 

/* joint space */
PVector           angles2                              = new PVector(0, 0);
PVector           torques2                             = new PVector(0, 0);

/* task space */
PVector           posEE2                               = new PVector(0, 0);
PVector           fEE2                                 = new PVector(0, 0); 


/* World boundaries reference */
final int         worldPixelWidth                     = 1000;
final int         worldPixelHeight                    = 650;


/* Initialization of virtual tool */
PShape            eeAvatar;
PShape            eeAvatar2;

ArrayList<PVector> positions = new ArrayList<PVector>();
int storePositions=50;

//Player 1
int travelledIndex=0;
PVector travelledPoint=new PVector(0,0);
float travelledDistance=0;
float totalDistance = 0;

//Player 2
int travelledIndex2=0;
PVector travelledPoint2=new PVector(0,0);
float travelledDistance2=0;
float totalDistance2 = 0;


boolean gameCompleted = false;

PFont f;
/* end elements definition *********************************************************************************************/ 



/* setup section *******************************************************************************************************/
void setup(){
  /* screen size definition */
  size(1000, 650);
  f                   = createFont("Arial", 16, true);
  
  println(Serial.list());
  /* device setup */
  haplyBoard          = new Board(this, Serial.list()[2], 0);
  haplyBoard2          = new Board(this, Serial.list()[3], 0);
  
  widgetOne           = new Device(widgetOneID, haplyBoard);
  widgetOne2           = new Device(widgetOneID, haplyBoard2);
  
  
  pantograph          = new Pantograph(hardwareVersion);
  pantograph2          = new Pantograph(hardwareVersion);
  
  widgetOne.set_mechanism(pantograph);
  widgetOne2.set_mechanism(pantograph2);
  
  if(hardwareVersion == 2){
    widgetOne.add_actuator(1, CCW, 2);
    widgetOne.add_actuator(2, CW, 1);
    widgetOne2.add_actuator(1, CCW, 2);
    widgetOne2.add_actuator(2, CW, 1);
 
    widgetOne.add_encoder(1, CCW, 241, 10752, 2);
    widgetOne.add_encoder(2, CW, -61, 10752, 1);
    widgetOne2.add_encoder(1, CCW, 241, 10752, 2);
    widgetOne2.add_encoder(2, CW, -61, 10752, 1);
  }
  else if(hardwareVersion == 3){
    widgetOne.add_actuator(1, CCW, 2);
    widgetOne.add_actuator(2, CCW, 1);
 
    widgetOne.add_encoder(1, CCW, 168, 4880, 2);
    widgetOne.add_encoder(2, CCW, 12, 4880, 1); 
  }
  
  
  widgetOne.device_set_parameters();
  widgetOne2.device_set_parameters();
  

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
  textFont(f, 50);
  fill(0, 150, 100);
  textAlign(CENTER);
  update_end_effector(eeAvatar, xE, yE, eeAvatar2, xE2, yE2);
  draw_path();
  if(gameCompleted){
    //print("1: "+totalDistance + " 2: "+totalDistance2);
    if(totalDistance>totalDistance2){
      text("Player1 won! ", width/2, height/2);
    }
    else if(totalDistance < totalDistance2){
      text("Player2 won! ", width/2, height/2);
    }
    else{
      text("It's a tie! ", width/2, height/2);
    }
    
  }
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
    if(haplyBoard2.data_available()){
      /* GET END-EFFECTOR STATE (TASK SPACE) */
      widgetOne2.device_read_data();
    
      angles2.set(widgetOne2.get_device_angles()); 
      posEE2.set(widgetOne2.get_device_position(angles2.array()));
      posEE2.set(device_to_graphics(posEE2)); 
  
      xE2 = (pixelsPerMeter * posEE2.x) + worldPixelWidth/2;
      yE2 = (pixelsPerMeter * (posEE2.y-0.03));
    }

    pathTrackingMiniGameStateUpdate();

    //print("posEE: "+posEE.x+" "+posEE.y+"\n");
    //print("xE: "+xE+" yE: "+yE+"\n");
    //println("---------------");
    //print("posEE2: "+posEE2.x+" "+posEE2.y+"\n");
    //print("xE2: "+xE2+" yE2: "+yE2+"\n");
   
    // posEE.x left to right: -0.12 to 0.1
    // posEE.y up to down: 0 to 0.16

    fEE = calculateForceTowardPath(travelledPoint, xE, yE);
    fEE2 = calculateForceTowardPath(travelledPoint2, xE2, yE2);

    fEE.set(graphics_to_device(fEE));
    fEE2.set(graphics_to_device(fEE2));

    torques.set(widgetOne.set_device_torques(fEE.array()));
    torques2.set(widgetOne2.set_device_torques(fEE2.array()));
    
    widgetOne.device_write_torques();
    widgetOne2.device_write_torques();
    
  
    rendering_force = false;
  }
}
/* end simulation section **********************************************************************************************/


/* helper functions section, place helper functions here ***************************************************************/
void update_end_effector(PShape ee, float xe, float ye, PShape ee2, float xe2, float ye2){
  background(255);
  
  int eeWidth=20;
  ee = createShape(ELLIPSE, xe, ye, eeWidth, eeWidth);
  ee.setFill(color(255,0,0));
  shape(ee);
  int eeWidth2=20;
  ee2 = createShape(ELLIPSE, xe2, ye2, eeWidth2, eeWidth2);
  ee2.setFill(color(0,255,0));
  shape(ee2);

}


ArrayList<PVector> squarePath = new ArrayList<PVector>();
ArrayList<PVector> squarePath2 = new ArrayList<PVector>();
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

  squarePath2.add(squarePath.get(0));
  for(int i=squarePath.size()-1;i>0;i--){
    squarePath2.add(squarePath.get(i));
  }
  println("sq1 "+squarePath);
  println("sq2 "+squarePath2);
  //Collections.reverse(squarePath2);
  travelledPoint.set(quadWidth, quadHeight);
  travelledPoint2.set(quadWidth, quadHeight);
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

  for (int i = travelledIndex2; i < travelledIndex2+1; i++) {
    PVector start = squarePath2.get(i);
    PVector end = squarePath2.get((i + 1) % squarePath2.size());
    beginShape();
    vertex(start.x, start.y);
    vertex(end.x, end.y);
    endShape(CLOSE);
  }

}

void draw_travelled_path() {
  noFill();
  //stroke(0,200,200);
  strokeWeight(pathWidth);
  totalDistance = 0;
  totalDistance2 = 0;
  
  if (travelledIndex >0) {
    stroke(0,200,200);
    for (int i = 0; i < travelledIndex; i++) {
      PVector start = squarePath.get(i);
      PVector end = squarePath.get((i + 1) % squarePath.size());
      totalDistance += start.copy().sub(end).mag();
      beginShape();
      vertex(start.x, start.y);
      vertex(end.x, end.y);
      endShape(CLOSE);
    }
  }

  if (travelledIndex2 >0) {
    for (int i = 0; i < travelledIndex2; i++) {
      stroke(200,0,200);
      PVector start = squarePath2.get(i);
      PVector end = squarePath2.get((i + 1) % squarePath2.size());
      totalDistance2 += start.copy().sub(end).mag();
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
  if (travelledIndex2 >= squarePath2.size()) {
    // for this player, it's already finished
    return ;
  }

  PVector start=squarePath.get(travelledIndex);
  PVector end=travelledPoint;
  totalDistance += start.copy().sub(end).mag();
  stroke(0,200,200);
  beginShape();
  vertex(start.x, start.y);
  vertex(end.x, end.y);
  endShape(CLOSE);

  PVector start2=squarePath2.get(travelledIndex2);
  PVector end2=travelledPoint2;
  totalDistance2 += start2.copy().sub(end2).mag();
  stroke(200,0,200);
  beginShape();
  vertex(start2.x, start2.y);
  vertex(end2.x, end2.y);
  endShape(CLOSE);
  stroke(0);
}


PVector lastLoopForceFeedback = new PVector(0, 0);

PVector calculateForceTowardPath(PVector travelledPt, float xe, float ye) {
  if (gameCompleted) {
    return new PVector(0, 0);
  }

  PVector forceDirection = PVector.sub(travelledPt, new PVector(xe, ye));
  float distance = forceDirection.mag();
  PVector forceFeedback = new PVector(0, 0);

  //print("distance: "+distance+"\n");
  // no force feedback if it's too close to the path, partly to reduce oscillation
  if (distance > 25) {
    forceDirection.normalize();
    //print("forceDirectionNormalized: "+forceDirection.x+" "+forceDirection.y+"\n");
    forceFeedback=forceDirection.mult(0.03*distance);
  }
  //print("forceFeedback: "+forceFeedback.x+" "+forceFeedback.y+"\n");

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
  int i2=travelledIndex2;

  PVector start = squarePath.get(i);
  PVector start2 = squarePath2.get(i2);
  PVector end = squarePath.get((i + 1) % squarePath.size());
  PVector end2 = squarePath2.get((i2 + 1) % squarePath2.size());

  PVector closest = getClosestPointOnLine(new PVector(xE, yE), start, end);
  PVector closest2 = getClosestPointOnLine(new PVector(xE2, yE2), start2, end2);
  
  float distanceEEandClosest = PVector.dist(new PVector(xE, yE), closest);
  float distanceEEandClosest2 = PVector.dist(new PVector(xE2, yE2), closest2);
  
  // too far from the path
  if (distanceEEandClosest > 40){
    return ;
  }
  if (distanceEEandClosest2 > 40){
    return ;
  }

  float nowTravelledDistance = PVector.dist(start, closest);
  float nowTravelledDistance2 = PVector.dist(start2, closest2);

  // it's jumping, not continuous movement along the path
  if (nowTravelledDistance - travelledDistance >50){
    return ;
  }
  if (nowTravelledDistance2 - travelledDistance2 >50){
    return ;
  }

  //  update the travelled distance and the travelled point
  if (nowTravelledDistance > travelledDistance) {
    travelledDistance = nowTravelledDistance;
    travelledPoint = closest;
  }
  if (nowTravelledDistance2 > travelledDistance2) {
    travelledDistance2 = nowTravelledDistance2;
    travelledPoint2 = closest2;
  }

  float fullDistance = PVector.dist(start, end);
  float fullDistance2 = PVector.dist(start2, end2);

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
  if (nowTravelledDistance2 > fullDistance2*0.99) {
    travelledDistance2 = 0;
    travelledIndex2 = travelledIndex2 + 1;
    
    if (travelledIndex2 == squarePath2.size()) {
      // game completed
      gameCompleted = true;
      return ;
    }

    travelledPoint = squarePath.get(travelledIndex);
    travelledPoint2 = squarePath2.get(travelledIndex2);
  }

  //println("dissssssssssstttt issss   "+ travelledPoint.copy().sub(travelledPoint2).mag());
  if(travelledPoint.copy().sub(travelledPoint2).mag()<=10 && (travelledIndex>1 || travelledIndex2>1)){
    gameCompleted = true;
    println("touched");
    text("Player won! ", width/2, height/2);
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
