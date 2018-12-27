//////////////////////////////////
//////     OS_RADAR v3.1    //////
//////////////////////////////////

/*
Date 2017/07/06

Created by Jasper Janssens for OLYMPIA STADION
a video installation by David Claerbout

This is a Processing v3.3.5 script written in Java
using the controlP5 library for the user interface

-----
Date 2018/02/05
v3.1 release

This version was reworked by Haryo Sukmawanto and reviewed by Jasper Janssens for OLYMPIA STADION
a video installation by David Claerbout

OS_Radar now displays the weatherValues and weatherMode in the GUI. 
It now also has a logger that will record these values for each session 
for up three weeks in a .csv file found in log/
*/

// import controlP5 library for UI
import controlP5.*;
import http.requests.*;

// some general variables
PImage webImg;
XML xmlWeatherData;
public int timer;

// variables for loading, using & saving config.xml
XML xmlConfig;
int positionX, positionY;
String xmlUrl;
String xmlWeatherDataFallback;
String xmlSave;
String imgLoad;
String imgLoadFallback;
String CurrentweatherMode;

// variables for analyzing the sampled pixel
float sampleH;
float sampleS;
float sampleB;

// variables for modifying the weather data
boolean isImgValid;
String weatherMode;
int weatherID;
float weatherValue;
float weatherClouds;

// variables for creation of UI controls
ControlP5 cp5;
Toggle t1, t2;
Numberbox n1;
Slider s1;

// variables for weather override, assigned to UI controls
boolean on_off = false;
boolean rain_snow = false;
boolean isOverridden = false;
float sliderValue = 50;
int timerOverride;;

// variables for logging
// Current* strings are set in logWeatherDataWriteRow()
// Init* Strings are used to set the start time of the log
Table logWeatherData;
String CurrentD, CurrentM, CurrentY, CurrentH, CurrentMin;
String InitD = nf(day(), 2);
String InitM = nf(month(), 2);
String InitY = nf(year(), 4);
String InitH = nf(hour(), 2);
String InitMin = nf(minute(), 2);
String weatherValueStr, weatherModeStr;

//////////////////////////////////
//////    SETUP FUNCTION    //////
//////////////////////////////////
// runs when you start the program

void setup ()  
{
  // set timer to 5 minute countdown
  timer = 15;
  
  // initialize variable
  isImgValid = true;
  
  // setup canvas width & height
  size (400,400);
  
  fill (50);
  rect (0, 0, width, 100);

  //////////////////////////////////
  //////   ADD UI CONTROLS    //////
  //////////////////////////////////
  // using ControlP5 library
 
 // initialize UI class
  cp5 = new ControlP5(this);  
  
  // add toggle for ON/OFF
  t1 = cp5.addToggle("on_off")
          .setPosition (10, 15)
          .setSize (40, 20)
          .setValue(false);
     
  // add toggle for rain or snow
  t2 = cp5.addToggle("rain_snow")
          .setPosition (80, 15)
          .setSize (40, 20)
          .setValue(true)
          .setMode(ControlP5.SWITCH);
     
  // add numberbox for setting the t mer
  n1 = cp5.addNumberbox("timerOverride")
          .setPosition(160,15)
          .setSize(80,20)
          .setRange(0,300)
          .setLabel ("Timer")
          .setValue(timer);
  
  // add slider for amount of precipitation
  s1 = cp5.addSlider ("sliderValue")
          .setPosition (10, 60)
          .setSize (100, 20)
          .setLabel ("Amount")
          .setRange (30,100);
          
  //////////////////////////////////
  //////   ADD UI CALLBACKS   //////
  //////////////////////////////////
  // using ControlP5 library
  // these functions allow interaction with the UI during runtime and give the UI controls their function
  
  // If toggle ON/OFF is activated, overwrite XML with set variables & set timer to timer override variable
  // if toggle ON/OFF is deactivated, reset timer to zero & let the normal process resume 
  t1.addCallback(new CallbackListener() 
  {
    public void controlEvent(CallbackEvent theEvent) 
    {
      if (theEvent.getAction()==ControlP5.ACTION_RELEASE && on_off == true) 
      {
        weatherOverride ();
        modifyWeatherData (true, weatherMode, weatherValue, weatherClouds);
        timer = timerOverride;
        displayReturnedValues ();
        logWeatherDataWriteRow();
      }
      
      if (theEvent.getAction()==ControlP5.ACTION_RELEASE && on_off == false) 
      {
        timer = 0;
      }
    }
  });
  
  // if toggle RAIN/SNOW is changed and toggle ON/OFF is activated, overwrite XML with set variables
  t2.addCallback(new CallbackListener() 
  {
    public void controlEvent(CallbackEvent theEvent) 
    {
      if (theEvent.getAction()==ControlP5.ACTION_RELEASE && on_off == true) 
      {
        weatherOverride ();
        modifyWeatherData (true, weatherMode, weatherValue, weatherClouds);
        displayReturnedValues ();
        logWeatherDataWriteRow();
      }
    }
  });
  
  // if slider VALUE is changed and toggle ON/OFF is activated, overwrite XML with set variables 
  s1.addCallback(new CallbackListener() 
  {
    public void controlEvent(CallbackEvent theEvent) 
    {
      if ((theEvent.getAction()==ControlP5.ACTION_RELEASE || theEvent.getAction()==ControlP5.ACTION_RELEASE_OUTSIDE) && on_off == true) 
      {
        weatherOverride ();
        modifyWeatherData (true, weatherMode, weatherValue, weatherClouds);
        displayReturnedValues ();
        logWeatherDataWriteRow();
      }
    }
  });
  
  // if numberbox TIMER OVERRIDE is changed and toggle ON/OFF is activated, set timer to new value
  n1.addCallback(new CallbackListener() 
  {
    public void controlEvent(CallbackEvent theEvent) 
    {
      if ((theEvent.getAction()==ControlP5.ACTION_RELEASE || theEvent.getAction()==ControlP5.ACTION_RELEASE_OUTSIDE)) 
      {
        timer = timerOverride;
      }
    }
  });
  
  ///////////////////////////////////////
  //////   RUN SCRIPT FIRST TIME   //////
  ///////////////////////////////////////
  loadWeatherIDTable();
  loadConfig ();
  logWeatherDataSetup();
  runScript ();
}

/////////////////////////////
//////   LOAD CONFIG   //////
/////////////////////////////

void loadConfig ()
{
  xmlConfig = loadXML ("config.xml");
  
  positionX = xmlConfig.getChild("imgPosition").getInt("x");
  positionY = xmlConfig.getChild("imgPosition").getInt("y");
  xmlUrl = xmlConfig.getChild("xmlWeatherData").getString("url");
  xmlWeatherDataFallback = xmlConfig.getChild("xmlWeatherDataFallback").getString("path");
  xmlSave = xmlConfig.getChild("xmlSaveLocation").getString("path"); // C:/Users/Administrator/Dropbox/Weatherdata/
  imgLoad = xmlConfig.getChild("imgLoad").getString("path");
  imgLoadFallback = xmlConfig.getChild("imgLoadFallback").getString("path");
}

/////////////////////////////////////
//////   RUN SCRIPT FUNCTION   //////
/////////////////////////////////////

void runScript ()
{
  if (webImg != null)
  {
    modifyWeatherData (isImgValid, weatherMode, weatherValue, weatherClouds);
  }
  else
  {
    modifyWeatherData (false, "no", 0, 0);
  }
  
  // run displayReturnedValues here after sampleImage is called and values are set
  displayReturnedValues ();
  
  // Log the weather data
  logWeatherDataWriteRow();
}

////////////////////////////////////////////////
//////    UI WEATHER OVERRIDE FUNCTION    //////
////////////////////////////////////////////////
// converts the variables set in the UI to variables used to modify the weather data XML

void weatherOverride ()
{
  // Set isOverridden boolean value
  isOverridden = true;
  
  if (rain_snow == true)
  { 
    weatherMode = "rain";
  }  
  else
  {
    weatherMode = "snow";
  }
        
  weatherValue = sliderValue;
  weatherClouds = map (sliderValue, 30, 100, 60, 100);
}

///////////////////////////////
//////   DRAW FUNCTION   //////
///////////////////////////////
// updates every frame

void draw ()
{
  // run TIMER FUNCTION
  setTimer ();
  
  // when timer runs out & weather override is OFF, reset timer & RUN SCRIPT FUNCTION
  if (timer <= 0 && on_off == false)
  {
    timer = 15;
    n1.setValue (timer);
    
    // Set isOverridden boolean value
    isOverridden = false;
    
    runScript ();
  }
}

//////////////////////////////////
//////    TIMER FUNCTION    //////
//////////////////////////////////

void setTimer ()
{
  // when the computer clock starts a new minute, decrease the timer value by 1
  if (second () == 0)
  {
    delay (2000);
    timer --;
    n1.setValue (timer);
    
    // if the weather override is ON, set it to OFF when the timer runs out
    if (timer <= 0 && on_off == true)
    {
      t1.setValue (false);
    }
  }
}

////////////////////////////////////////////////
//////    MODIFY WEATHER DATA FUNCTION    //////
////////////////////////////////////////////////
// loads the XML file from OpenWeatherMap and changes the precipitation & clouds elements to the new variables

void modifyWeatherData (boolean isImgValid, String mode, float value, float clouds)
{
  // Load XML file from OpenWeatherMap. If not valid, load xmlWeatherDataFallback
  // Try loading xmlWeatherData. 
  try {
    xmlWeatherData = loadXML(xmlUrl);
  }
  catch(Exception e) {
    print("xmlWeatherData could not be loaded");
    print("loading fallback data");
    xmlWeatherData = loadXML(xmlWeatherDataFallback);
  }
  // if image is black (faulty screenshot) set the date back to january 2016 so it gets rejected
  if (isImgValid == false)
  {
    XML xmlDate = xmlWeatherData.getChild ("lastupdate");
    xmlDate.setString ("value", "2016-01-01T00:00:00");
  }
  
  // Get weather code from XML
  XML xmlWeather = xmlWeatherData.getChild("weather");
  weatherID = int(xmlWeather.getString("number"));
  
  weatherMode = GetPrecipitationModeFromTable(WeatherIDTable, weatherID);
  weatherValue = float(GetValueFromTable(WeatherIDTable, weatherID));

  
  // set mode of precipitation and value of precipitation
  XML xmlPrecipitation = xmlWeatherData.getChild ("precipitation");
  xmlPrecipitation.setString("mode", GetPrecipitationModeFromTable(WeatherIDTable, weatherID));
  xmlPrecipitation.setString("value", nf(GetValueFromTable(WeatherIDTable, weatherID)));

  // save altered XML file
  saveXML (xmlWeatherData, xmlSave);
}


//////////////////////////////////////////
/////     AUXILIARY FUNCTIONS        /////
//////////////////////////////////////////

// This function displays weatherValue and weatherMode in the GUI
void displayReturnedValues() 
{
  fill (50);
  noStroke();
  //debug stroke drawing:
  //stroke(255,255,255);
  //strokeWeight(1);
  rect(160, 50, 160, 40);
  rect(245, 10, 75, 50);
  
  fill(255);
  
  //Convert weatherValue to a string variable and displays it
  weatherValueStr = nf(weatherValue);
  text(weatherValueStr, 160, 60, 30, 20);
  text("weatherValue", 160, 85);
  
  //Checks weatherMode and displays Snow, Rain or None depending on the conditions
  weatherModeStr = GetPrecipitationModeFromTable(WeatherIDTable, weatherID);
  
  text(weatherModeStr, 240, 60, 40, 20);
  text("weatherMode", 240, 85);
  
  //Display time last updated
  CurrentD = nf(day(), 2);
  CurrentM = nf(month(), 2);
  CurrentY = nf(year(), 4);
  CurrentH = nf(hour(), 2);
  CurrentMin = nf(minute(), 2);

  text("Last updated", 245, 25);
  text(CurrentY + "/" + CurrentM + "/" + CurrentD, 245, 42);
  text(CurrentH + "h" + CurrentMin, 245, 55);
    
}


// Adds a logger to the program to keep track of changes to Olympia
// Setup logWeatherData as a new Table
void logWeatherDataSetup()
{
  logWeatherData = new Table();
  
  // Add column headers to logWeatherData
  logWeatherData.addColumn("Date");
  logWeatherData.addColumn("Time");
  logWeatherData.addColumn("WeatherOverride");
  logWeatherData.addColumn("WeatherMode");
  logWeatherData.addColumn("WeatherValue");
  logWeatherData.addColumn("Clouds"); 
  logWeatherData.addColumn("Temperature");
  logWeatherData.addColumn("WindDirection"); 
  logWeatherData.addColumn("WindSpeed"); 
}

// Function that will write the values to the log
void logWeatherDataWriteRow()
{ 
  //Define date and time the moment the log entry is written
  CurrentD = nf(day(), 2);
  CurrentM = nf(month(), 2);
  CurrentY = nf(year(), 4);
  CurrentH = nf(hour(), 2);
  CurrentMin = nf(minute(), 2);
  
  String cloudsStr = xmlWeatherData.getChild ("clouds").getString("value");
  String tempValueStr = xmlWeatherData.getChild ("temperature").getString("value");
  String windCodeStr = xmlWeatherData.getChild ("wind").getChild("direction").getString("code");
  String windValueStr = xmlWeatherData.getChild ("wind").getChild("speed").getString("value");
  
  // Check length of table, if it exceeds an amount then delete the first row
  // and write new row after
  if (logWeatherData.getRowCount() >= 2000)
  {
    logWeatherData.removeRow(0);
    TableRow newRow = logWeatherData.addRow();
    
    newRow.setString("Date", CurrentY + "/" + CurrentM + "/" + CurrentD);
    newRow.setString("Time", CurrentH + ":" + CurrentMin);
    newRow.setString("WeatherOverride", str(isOverridden));
    newRow.setString("WeatherMode", weatherModeStr);
    newRow.setString("WeatherValue", weatherValueStr);
    newRow.setString("Clouds", cloudsStr); 
    newRow.setString("Temperature", tempValueStr);
    newRow.setString("WindSpeed", windValueStr);
    newRow.setString("WindDirection", windCodeStr);
  }
  else
  { 
    TableRow newRow = logWeatherData.addRow();
    newRow.setString("Date", CurrentY + "/" + CurrentM + "/" + CurrentD);
    newRow.setString("Time", CurrentH + ":" + CurrentMin);
    newRow.setString("WeatherOverride", str(isOverridden));
    newRow.setString("WeatherMode", weatherModeStr);
    newRow.setString("WeatherValue", weatherValueStr);
    newRow.setString("Clouds", cloudsStr); 
    newRow.setString("Temperature", tempValueStr);
    newRow.setString("WindSpeed", windValueStr);
    newRow.setString("WindDirection", windCodeStr);
  }
   
  //Takes the Init* date and time variables as the logfile name
  saveTable(logWeatherData, "log/" + InitY + InitM + InitD + "-" + InitH + "h" + InitMin + ".csv");
}

// Sends a GET request to input URL and returns whether URL is OK
boolean isURLOK(String URL)
{
  GetRequest URLGetRequest = new GetRequest(URL);
  URLGetRequest.send();
  
  if (URLGetRequest.getHeader("Status") == "Status: 200 OK")
  {
    return true;
  }
  else
  {
    return false;
  }
}