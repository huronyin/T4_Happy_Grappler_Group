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


// device config
String port1 =  "COM5";
String port2 =  "COM6";
int hardwareVersion = 3;


/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);
/* end scheduler definition ********************************************************************************************/ 

boolean           renderingForce                      = false;

/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 60;
/* end framerate definition ********************************************************************************************/ 



/* elements definition *************************************************************************************************/


/* Screen and world setup parameters */
float             pixelsPerCentimeter                 = 40.0;

/* World boundaries in centimeters */
FWorld            world;
float             worldWidth                          = 25;  
float             worldPixelWidth                     = worldWidth*pixelsPerCentimeter;
float             worldHeight                         = 25; 
float             worldPixelHeight                     = worldHeight*pixelsPerCentimeter;
float             edgeTopLeftX                        = 0.0; 
float             edgeTopLeftY                        = 0.0; 
float             edgeBottomRightX                    = worldWidth; 
float             edgeBottomRightY                    = worldHeight;


/* Initialization of walls */
FBox              wall;

/* Initialization of avatars */
HaplyAvatar       avatar1;
HaplyAvatar       avatar2;

/* Minigame stuff */
PFont f;
float pathWidth = 20; // Adjust the width of the path as desired
boolean           isMinigame                          = false;
int               inDangerID                          = 0;
boolean           miniGameCompleted                   = false;
int               miniGameEndTime;


/* Startup stuff */
int               startDelayMillis                    = 8000;

/* end elements definition *********************************************************************************************/ 



/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once: */
  
  /* screen size definition */
  size(1000, 1000);
  
  /* device setup */

  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world               = new FWorld();
  
  /* Haply avatar initialization */
  avatar1 = new HaplyAvatar(port1, world,1,hardwareVersion);
  avatar2 = new HaplyAvatar(port2, world,2,hardwareVersion);

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

  /* Minigame setup */
  f                   = createFont("Arial", 16, true);
  

  /* setup simulation thread to run at 1kHz */ 
  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 1, MILLISECONDS);
}
/* end setup section ***************************************************************************************************/



/* draw section ********************************************************************************************************/
void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  
  
  
  if(renderingForce == false){
    if (!isMinigame){
      background(255);
      if (millis() < startDelayMillis){
        textFont(f, 50);
        fill(0,0,0);
        textAlign(CENTER);
        text("Get ready!", worldPixelWidth/2, worldPixelHeight/2);
      }
      world.draw();
    }
    else{
      background(200); 
      textFont(f, 50);
      fill(0,0,0);
      textAlign(CENTER);
      avatar1.minigame_drawDirectionCues();
      avatar2.minigame_drawDirectionCues();
      avatar1.minigame_drawUntravelledPath();
      avatar2.minigame_drawUntravelledPath();
      avatar1.minigame_drawTravelledPath();
      avatar2.minigame_drawTravelledPath();
      avatar1.minigame_drawEE();
      avatar2.minigame_drawEE();
      
      if(miniGameCompleted){
        if(avatar1.totalDistance>avatar2.totalDistance && (inDangerID == 2)){
          text("Player1 won!", worldPixelWidth/2, worldPixelHeight/2);
        }
        else if(avatar1.totalDistance < avatar2.totalDistance && (inDangerID == 1)){
          text("Player2 won!", worldPixelWidth/2, worldPixelHeight/2);
        }
        else{
          text("Safe! Reset to original position", worldPixelWidth/2, worldPixelHeight/2);
          avatar1.sh_avatar.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+2*worldHeight/7.0);
          avatar2.sh_avatar.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+2*worldHeight/5.0);
        }
      }
    }
  }
}
/* end draw section ****************************************************************************************************/



/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable{
  
  public void run(){
    /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
    renderingForce = true;
    
    if (!isMinigame){
      avatar1.run();
      avatar2.run();
      
      if(millis()>startDelayMillis){
        world.step(1.0f/1000.0f);
      }
    }

    else{
      avatar1.minigame_getHaplyData();
      avatar2.minigame_getHaplyData();
      //println("av1 x: "+ avatar1.posEE.x+"av1 y: "+avatar1.posEE.y);
      //println("av2 x: "+ avatar2.posEE.x+"av2 y: "+avatar2.posEE.y);

      avatar1.minigame_stateUpdate();
      avatar2.minigame_stateUpdate();
      

      avatar1.minigame_renderForce();
      avatar2.minigame_renderForce();

      //to check if players have come in contact and game has ended
      if(avatar1.travelledPoint.copy().sub(avatar2.travelledPoint).mag()<=10 && (avatar1.travelledIndex>1 || avatar2.travelledIndex>1)){
        if(!miniGameCompleted){
          miniGameCompleted = true;
          miniGameEndTime = millis();
        }
      }

      //to exit minigame mode 5 seconds after the game finishes and the  winner is declared.
      if(millis() - miniGameEndTime >= 5000 && miniGameCompleted){
        avatar1.minigame_reset();
        avatar2.minigame_reset();
        isMinigame = !isMinigame;
        miniGameCompleted = false;
        //println("mini game has now endeddddd");
      }

    }
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/

void keyPressed() {
  if (key == 'o') {
    //isMinigame = !isMinigame;
  }
}

public class HaplyAvatar{
    /* device block definitions ********************************************************************************************/
    Board             haplyBoard;
    Device            widget;
    Mechanisms        pantograph;

    byte              widgetID                            = 5;
    int               CW                                  = 0;
    int               CCW                                 = 1;
    boolean           renderingForce                      = false;
    int               id;
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
    PVector           xSpring                             = new PVector(0, 0.12);

    /* Initialization of fisica stuff */
    FWorld            world;
    FCircle           sh_avatar;

    /* Virtual avatar parameters */
    float             movementSpeed = 1.0e2;
    float             reactionMult = 2;
    String            name;

    /* initializing virtual avatar variables */
    PImage            haplyAvatar;
    ArrayList<FContact>         contactList                          = null;

    /* USB port */
    String            port = "";

    /* Minigame variables */
    ArrayList<PVector> squarePath = new ArrayList<PVector>();
    int travelledIndex=0;
    PVector travelledPoint=new PVector(0,0);
    float travelledDistance=0;
    float totalDistance = 0;
    float xE;
    float yE;
    int colour;
    float minigame_scaling = 2.5;
    int version;
    PShape ee;
    PShape directionCueShape;
    int directionCueIncrementer=0;

    public HaplyAvatar(String port, FWorld world, int id, int version){
        this.port = port;
        this.world = world;
        this.id = id;
        this.version=version;
    }

    public void setup(PApplet app){
        haplyBoard          = new Board(app, port, 0);
        widget              = new Device(widgetID, haplyBoard);
        pantograph          = new Pantograph(version);
        
        widget.set_mechanism(pantograph);

        if(version == 2){
          widget.add_actuator(1, CCW, 2);
          widget.add_actuator(2, CW, 1);
      
          widget.add_encoder(1, CCW, 241, 10752, 2);
          widget.add_encoder(2, CW, -61, 10752, 1);
        }
        else if(version == 3){
          widget.add_actuator(1, CCW, 2);
          widget.add_actuator(2, CCW, 1);
      
          widget.add_encoder(1, CCW, 168, 4880, 2);
          widget.add_encoder(2, CCW, 12, 4880, 1); 
        }
          
        widget.device_set_parameters();

        sh_avatar = new FCircle(1.8);
        sh_avatar.setDensity(4);  
        if(id == 1){
          sh_avatar.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+2*worldHeight/7.0); 
          sh_avatar.setName("avatar1");
          this.name = "avatar1";
        }
        else{
          sh_avatar.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+2*worldHeight/5.0); 
          sh_avatar.setName("avatar2");
          this.name = "avatar2";
        }
        
        sh_avatar.setHaptic(true, 1000, 1);
        world.add(sh_avatar);

        if(id == 1){
          haplyAvatar = loadImage("img/smile.png"); 
        }
        else{
          haplyAvatar = loadImage("img/smile2.png"); 
        }
        
        haplyAvatar.resize((int)(hAPI_Fisica.worldToScreen(1.8)), (int)(hAPI_Fisica.worldToScreen(1.8)));
        sh_avatar.attachImage(haplyAvatar); 

        minigame_generateSquarePath();

        if(id == 1){
          colour = color(243,236,25);
        }
        else{
          colour = color(34,177,76);
        }
    }

    public void run(){
        /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
        
        if(haplyBoard.data_available()){
            /* GET END-EFFECTOR STATE (TASK SPACE) */
            widget.device_read_data();
            
            angles.set(widget.get_device_angles()); 
            posEE.set(widget.get_device_position(angles.array()));
            //print(posEE.x);
            //print(",");
            //print(posEE.y);
            //print("\n");
        }
        
        // calculate deltaXSpring
        deltaXSpring = posEE.sub(xSpring);
        
        // move avatar based on deltaXSpring
        sh_avatar.setVelocity(-deltaXSpring.x * movementSpeed, deltaXSpring.y * movementSpeed);
            
        // calculate restoring joycon force
        fSpring.set(0, 0);
        fSpring = fSpring.add(deltaXSpring.mult(-kSpring));
        fEE = (fSpring.copy());
        
        // get contacts
        contactList = sh_avatar.getContacts();
        
        for(int i=0;i<contactList.size();i++)
        {
          // check for red wall collision
          if(contactList.get(i).getBody1().getFillColor() == color(255,0,0)){
            inDangerID = id;
            isMinigame = true;
          }
          else if(contactList.get(i).getBody2().getFillColor() == color(255,0,0)){
            inDangerID = id;
            isMinigame = true;
          }
          
          // calculate collision reaction forces
          if(contactList.get(i).getBody2().getName() == this.name){
            fEE.add(contactList.get(i).getVelocityX() * reactionMult, -contactList.get(i).getVelocityY() * reactionMult);            
          }
          else{
            fEE.add(-contactList.get(i).getVelocityX() * reactionMult, contactList.get(i).getVelocityY() * reactionMult);            
          }

        }
        
        torques.set(widget.set_device_torques(fEE.array()));
        widget.device_write_torques();
    }

    void minigame_reset(){
      this.squarePath = new ArrayList<PVector>();
      this.travelledIndex=0;
      this.travelledPoint=new PVector(0,0);
      this.travelledDistance=0;
      this.totalDistance = 0;
      
      minigame_generateSquarePath();
    }

    void minigame_drawEE(){
      ee = createShape(ELLIPSE, xE, yE, 20, 20);
      ee.setStroke(colour);
      shape(ee);
    }

    void minigame_drawDirectionCues(){
      if(id==2){
        directionCueShape = createShape(TRIANGLE, directionCueIncrementer + 320, 710, directionCueIncrementer + 320, 730, directionCueIncrementer+330, 720);
        directionCueShape.setStroke(colour);
        directionCueIncrementer += 1; // Increment x-coordinate
  
        if(directionCueIncrementer > 350){
          directionCueIncrementer = 0;
        }
      }
      else{
        directionCueShape = createShape(TRIANGLE, 265, directionCueIncrementer + 690, 285, directionCueIncrementer + 690, 275, directionCueIncrementer+680);
        directionCueShape.setStroke(colour);
        directionCueIncrementer -= 1; // Increment y-coordinate
  
        if(directionCueIncrementer < -350){
          directionCueIncrementer = 0;
        }
      }
      shape(directionCueShape);
    }

    void minigame_getHaplyData(){
      if(haplyBoard.data_available()){
        /* GET END-EFFECTOR STATE (TASK SPACE) */
        widget.device_read_data();
        angles.set(widget.get_device_angles()); 
        posEE.set(widget.get_device_position(angles.array()));
        // posEE.set(device_to_graphics(posEE));
        // TODO: Ask the user to move EE to given position
        float xECalib = 0;
        if (id == 1){
          xECalib = 0.05;
        }
        else{
          xECalib = 0.06;
        }
        xE = -(minigame_scaling *pixelsPerCentimeter *100 * (posEE.x+xECalib)) + worldWidth*minigame_scaling*pixelsPerCentimeter/2;
        yE = (minigame_scaling *pixelsPerCentimeter *100 * (posEE.y-0.03));
        // xE = (pixelsPerCentimeter *100 * posEE.x) + worldWidth*pixelsPerCentimeter/2;
        // yE = (pixelsPerCentimeter *100 * (posEE.y-0.03));
        //println("Minigame posEE:"+posEE.x+","+posEE.y+"; xE:"+xE+"; yE:"+yE);
      }
    }

    void minigame_renderForce(){
      fEE = calculateForceTowardPath(travelledPoint, xE, yE);
      fEE.set(graphics_to_device(fEE));
      torques.set(widget.set_device_torques(fEE.array()));
      widget.device_write_torques();
    }

    void minigame_drawUntravelledPath() {
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

    void minigame_drawTravelledPath() {
      noFill();
      strokeWeight(pathWidth);
      totalDistance = 0;
  
      if (travelledIndex >0) {
        stroke(colour);
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
  
      if (travelledIndex >= squarePath.size()) {
        // for this player, it's already finished
        return ;
      }

      PVector start=squarePath.get(travelledIndex);
      PVector end=travelledPoint;
      totalDistance += start.copy().sub(end).mag();
      stroke(colour);
      beginShape();
      vertex(start.x, start.y);
      vertex(end.x, end.y);
      endShape(CLOSE);
    }

    void minigame_stateUpdate() {
      int i=travelledIndex;

      PVector start = squarePath.get(i);
      PVector end = squarePath.get((i + 1) % squarePath.size());

      PVector closest = getClosestPointOnLine(new PVector(xE, yE), start, end);
      
      float distanceEEandClosest = PVector.dist(new PVector(xE, yE), closest);
      float nowTravelledDistance = PVector.dist(start, closest);
      float travelledIncrementDistance = nowTravelledDistance - travelledDistance;

      if ((distanceEEandClosest <= 40) && ( travelledIncrementDistance<50) && (travelledIncrementDistance>0)){
        // this player is moving forward!
        travelledDistance = nowTravelledDistance;
        travelledPoint = closest;
        float fullDistance = PVector.dist(start, end);
        if (nowTravelledDistance > fullDistance*0.99) {
          travelledDistance = 0;
          travelledIndex = travelledIndex + 1;
          travelledPoint = squarePath.get(travelledIndex);
        }
      }
      /*if(travelledPoint.copy().sub(travelledPoint2).mag()<=10 && (travelledIndex>1 || travelledIndex2>1)){
        gameCompleted = true;
        println("touched");
        text("Player won! ", width/2, height/2);
      }*/
    }

    void minigame_generateSquarePath() {
      // TODO: path generation should be a helper function, avatar takes in a vector<point> as path
      // 
        // squarePath2.add(squarePath.get(0));
        // for(int i=squarePath.size()-1;i>0;i--){
        //   squarePath2.add(squarePath.get(i));
        // }

      float centerX = worldPixelWidth / 2;
      float centerY = worldPixelHeight / 2;
      float quadWidth = (centerX - pathWidth / 2)/3;
      float quadHeight = (centerY - pathWidth / 2)/3;

      if (id == 1){
        squarePath.add(new PVector(centerX - quadWidth, centerY + quadHeight));
        squarePath.add(new PVector(centerX - quadWidth, centerY - quadHeight));
        squarePath.add(new PVector(centerX + quadWidth, centerY - quadHeight));
        squarePath.add(new PVector(centerX + quadWidth, centerY + quadHeight));
      }
      else{
        squarePath.add(new PVector(centerX - quadWidth, centerY + quadHeight));
        squarePath.add(new PVector(centerX + quadWidth, centerY + quadHeight));
        squarePath.add(new PVector(centerX + quadWidth, centerY - quadHeight));
        squarePath.add(new PVector(centerX - quadWidth, centerY - quadHeight));
      }
      //println("sq1 "+squarePath);
      travelledPoint.set(centerX - quadWidth, centerY + quadHeight);
    }
}

/* helper functions section, place helper functions here ***************************************************************/

PVector getClosestPointOnLine(PVector point, PVector start, PVector end) {
  PVector lineVector = PVector.sub(end, start);
  PVector pointVector = PVector.sub(point, start);
  float projectionLength = pointVector.dot(lineVector) / lineVector.magSq();
  projectionLength = constrain(projectionLength, 0, 1);
  return PVector.add(start, PVector.mult(lineVector, projectionLength));
}

PVector calculateForceTowardPath(PVector travelledPt, float xe, float ye) {
  PVector forceDirection = PVector.sub(travelledPt, new PVector(xe, ye));
  float distance = forceDirection.mag();
  PVector forceFeedback = new PVector(0, 0);

  // no force feedback if it's too close to the path, partly to reduce oscillation
  if (distance > 25) {
    forceDirection.normalize();
    forceFeedback=forceDirection.mult(0.02*distance);
  }
  return forceFeedback;
}

PVector device_to_graphics(PVector deviceFrame){
  return deviceFrame.set(-deviceFrame.x, deviceFrame.y);
}

PVector graphics_to_device(PVector graphicsFrame){
  return graphicsFrame.set(-graphicsFrame.x, graphicsFrame.y);
}
/* end helper functions section ****************************************************************************************/
