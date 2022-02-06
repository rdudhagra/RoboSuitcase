#include <L298N.h>
#include <Servo.h>
#include <ESP8266WiFi.h>
#include <ESPAsyncTCP.h>
#include <ESPAsyncWebServer.h>


#define servoPin 2  // 4

Servo my_servo;

// Pin definition
const unsigned int IN1 = 4;  // 2
const unsigned int IN2 = 0;  // 3
const unsigned int EN = 14;  // 5

// Create one motor instance
L298N motor(EN, IN1, IN2);

// Replace with your network credentials
const char* ssid     = "CMU-DEVICE";
const char* password = "";

AsyncWebServer server(80);


void setup()
{
  // Used to display information
  Serial.begin(115200);

  my_servo.attach(servoPin);
  
  // Connect to Wi-Fi network with SSID and password
  Serial.print("Connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  // Print local IP address and start web server
  Serial.println("");
  Serial.println("WiFi connected.");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());

  // Main route
  server.on("/servo", HTTP_GET, [](AsyncWebServerRequest * request)
  {
    if (request->hasParam("angle"))
    {
      handleServo(request->getParam("angle")->value().toInt());
      request->send(200, "text/plain", "suitcase");
    }
  });

  // Main route
  server.on("/motor", HTTP_GET, [](AsyncWebServerRequest * request)
  {
    if (request->hasParam("angle") && request->hasParam("speed"))
    {
      handleServo(request->getParam("angle")->value().toInt());
      handleMotor(0,
                  request->getParam("speed")->value().toInt());
      request->send(200, "text/plain", "suitcase");
    }
  });
  server.begin();
}

void loop()
{

}

void handleServo(unsigned int angle) {
  if (angle > 180) angle = 180;
  my_servo.write(angle);
  Serial.print("angle: ");
  Serial.println(angle);
}

void handleMotor(unsigned int motor_dir, unsigned int motor_speed) {
  if (motor_dir > 1) motor_dir = 1;
  if (motor_speed > 255) motor_speed = 255;
  setMotorSpeed(motor_speed);
  Serial.print("motor_dir: ");
  Serial.print(motor_dir);
  Serial.print(" motor_speed: ");
  Serial.println(motor_speed);
}

void setMotorSpeed(unsigned int motor_speed)
{
  if (motor_speed < 70)
    motor.stop();
  else {
    motor.setSpeed(motor_speed);
    motor.backward();
  }
}
