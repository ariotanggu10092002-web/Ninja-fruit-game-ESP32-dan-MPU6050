#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

Adafruit_MPU6050 mpu;

const int TOUCH_SIGNAL_PIN = 4; // Kabel di Jari Jempol
const int LED_PIN = 2;          // LED internal ESP32

// Variabel Kalibrasi
float gyroX_offset = 0;
float gyroY_offset = 0;
bool mpuReady = false;

// Parameter Sensor
const float SMOOTHING_FACTOR = 0.25; 
const float DEADZONE = 0.06;         
const int SENSITIVITY = 35;          
const float MOTION_THRESHOLD = 15.0; 

float smoothedGyroX = 0;
float smoothedGyroY = 0;

void setup() {
  Serial.begin(115200);
  
  pinMode(TOUCH_SIGNAL_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);

  // Inisialisasi I2C (SDA Pin 21, SCL Pin 22)
  Wire.begin(21, 22); 
  
  if (mpu.begin(0x68) || mpu.begin(0x69)) {
    mpuReady = true;
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    
    // Kalibrasi Awal Gyroscope
    digitalWrite(LED_PIN, HIGH); 
    sensors_event_t a, g, temp;
    for (int i = 0; i < 50; i++) {
      mpu.getEvent(&a, &g, &temp);
      gyroX_offset += g.gyro.x;
      gyroY_offset += g.gyro.y;
      delay(5);
    }
    gyroX_offset /= 50;
    gyroY_offset /= 50;
    digitalWrite(LED_PIN, LOW);
  }
}

void loop() {
  // Jika koneksi sensor bermasalah, kirim data kosong/nol agar Processing tidak crash
  if (!mpuReady) {
    if (mpu.begin(0x68) || mpu.begin(0x69)) {
      mpuReady = true;
      mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    }
    // Kirim data nol (10 kolom) sebagai penanda sensor tidak siap
    Serial.println("0,0,0.00,0.00,0.00,0.0,0.0,0,0,0");
    delay(500);
    return; 
  }

  sensors_event_t a, g, temp;
  
  if (!mpu.getEvent(&a, &g, &temp)) {
    mpuReady = false;
    return;
  }

  // 1. DATA GYROSCOPE (Kolom 1 & 2)
  float rawCorrectedX = g.gyro.y - gyroY_offset; 
  float rawCorrectedY = g.gyro.x - gyroX_offset; 
  smoothedGyroX = (SMOOTHING_FACTOR * rawCorrectedX) + ((1.0 - SMOOTHING_FACTOR) * smoothedGyroX);
  smoothedGyroY = (SMOOTHING_FACTOR * rawCorrectedY) + ((1.0 - SMOOTHING_FACTOR) * smoothedGyroY);
  int moveX = 0; int moveY = 0;
  if (abs(smoothedGyroX) > DEADZONE) moveX = smoothedGyroX * SENSITIVITY; 
  if (abs(smoothedGyroY) > DEADZONE) moveY = smoothedGyroY * -SENSITIVITY; 

  // 2. DATA ACCELEROMETER (Kolom 3, 4, 5)
  float accX = a.acceleration.x;
  float accY = a.acceleration.y;
  float accZ = a.acceleration.z;

  // 3. DATA SUDUT KEMIRINGAN (Kolom 6 & 7)
  float roll  = atan2(accY, accZ) * 180.0 / M_PI;
  float pitch = atan2(-accX, sqrt(accY * accY + accZ * accZ)) * 180.0 / M_PI;

  // 4. DETEKSI GERAKAN/GUNCANGAN (Kolom 8)
  float totalAcceleration = sqrt(accX * accX + accY * accY + accZ * accZ);
  int motionDetected = (totalAcceleration > MOTION_THRESHOLD) ? 1 : 0;

  // 5. PERUBAHAN ORIENTASI (Kolom 9)
  int orientation = 0; 
  if (accZ > 7.0)       orientation = 1; // Datar Atas
  else if (accZ < -7.0) orientation = 2; // Terbalik
  else if (accX > 7.0)  orientation = 3; // Miring Kanan
  else if (accX < -7.0) orientation = 4; // Miring Kiri

  // 6. KABEL SENTUH (Kolom 10)
  int clickStatus = (digitalRead(TOUCH_SIGNAL_PIN) == LOW) ? 1 : 0;

  // 7. PENGIRIMAN MURNI ANGKA DAN KOMA (Wajib Baris Tunggal)
  Serial.print(moveX);            Serial.print(","); // Kolom 1
  Serial.print(moveY);            Serial.print(","); // Kolom 2
  Serial.print(accX, 2);          Serial.print(","); // Kolom 3
  Serial.print(accY, 2);          Serial.print(","); // Kolom 4
  Serial.print(accZ, 2);          Serial.print(","); // Kolom 5
  Serial.print(roll, 1);          Serial.print(","); // Kolom 6
  Serial.print(pitch, 1);         Serial.print(","); // Kolom 7
  Serial.print(motionDetected);   Serial.print(","); // Kolom 8
  Serial.print(orientation);      Serial.print(","); // Kolom 9
  Serial.println(clickStatus);                       // Kolom 10 (Akhir baris)

  delay(15); // Delay cepat agar responsif di Processing
}


