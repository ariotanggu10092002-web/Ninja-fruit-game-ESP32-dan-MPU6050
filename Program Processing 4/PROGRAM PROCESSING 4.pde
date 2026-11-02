import processing.serial.*;

Serial myPort;
// Penguncian titik tengah baru sesuai kalibrasi manual Anda
volatile float targetX = 525;
volatile float targetY = 400;
float cursorX = 525, cursorY = 400; 
float prevX = 525, prevY = 400; 

// Variabel Penyerapan Bias Hardware MPU6050
float gyroX_bias = 0;
float gyroY_bias = 0;
int calibrationCounter = 0;
boolean isCalibrated = false;

ArrayList<PVector> trail = new ArrayList<PVector>(); 
ArrayList<Fruit> fruits = new ArrayList<Fruit>();
ArrayList<Particle> particles = new ArrayList<Particle>(); 
ArrayList<SlicedHalf> slicedHalves = new ArrayList<SlicedHalf>(); 
ArrayList<JuiceStain> juiceStains = new ArrayList<JuiceStain>(); 
ArrayList<SliceFlash> flashes = new ArrayList<SliceFlash>(); 

float baseGravity = 0.22; 
float currentGravity = 0.22;
float speedMultiplier = 1.0; 
int score = 0;
int gameTime = 0; 
boolean gameOver = false;
float spawnTimer = 0;
float spawnInterval = 55; 
String causeOfGameOver = "WAKTU SELESAI!"; 

void setup() {
  size(1000, 700, P2D); // Mode P2D Akselerasi Grafik Vector Super Lancar 60 FPS
  frameRate(60);
  
  try {
    String portName = "COM3"; 
    myPort = new Serial(this, portName, 115200);
    myPort.bufferUntil('\n'); 
  } catch (Exception e) {
    println("Serial port tidak terdeteksi. Otomatis menggunakan Mode MOUSE.");
    myPort = null;
  }
}

// =========================================================================
// PERBAIKAN FIXED: Pemetaan Absolut Terpusat di Koordinat X: 525 dan Y: 400
// =========================================================================
void serialEvent(Serial p) {
  try {
    String inString = p.readStringUntil('\n');
    if (inString != null) {
      inString = trim(inString);
      float[] data = float(split(inString, ','));
      
      if (data.length >= 10) {
        float rawGyroX = data[0]; 
        float rawGyroY = data[1]; 
        
        // PROSEDUR KALIBRASI BIAS ELEKTRONIK (Menghitung rata-rata 60 data pertama)
        if (!isCalibrated) {
          gyroX_bias += rawGyroX;
          gyroY_bias += rawGyroY;
          calibrationCounter++;
          
          if (calibrationCounter >= 60) {
            gyroX_bias /= 60.0;
            gyroY_bias /= 60.0;
            isCalibrated = true;
          }
          return; 
        }
        
        // 1. Bersihkan noise dari data mentah
        float gyroX = rawGyroX - gyroX_bias;
        float gyroY = rawGyroY - gyroY_bias;
        
        // 2. Filter getaran tangan mikro (Deadzone)
        if (abs(gyroX) < 0.35) gyroX = 0;
        if (abs(gyroY) < 0.35) gyroY = 0;
        
        if (gyroX == 0 && gyroY == 0) {
          // JIKA DIAM: Kunci paksa tepat di titik tengah baru Anda (525, 400)
          targetX = 525;
          targetY = 400;
        } else {
          // JIKA BERGERAK: Petakan pergeseran sudut murni dimulai dari titik (525, 400)
          targetX = 525 + (gyroX * 11.5); 
          targetY = 400 + (gyroY * 11.5); 
        }
      }
    }
  } catch (Exception e) {}
}
void draw() {
  if (myPort == null) {
    targetX = mouseX; targetY = mouseY;
  }

  // Pengunci batas gerak kursor aman di dalam window permainan dengan padding luas
  targetX = constrain(targetX, 25, width - 25);
  targetY = constrain(targetY, 25, height - 25);

  prevX = cursorX; prevY = cursorY;
  
  // Kombinasi elastis lerp dipercepat ke 0.25 agar kursor silet terasa instan dan tidak ada delay
  cursorX = lerp(cursorX, targetX, 0.25); 
  cursorY = lerp(cursorY, targetY, 0.25);

  // =========================================================================
  // FIX AKHIR SILET BERHENTI: NON-ZERO GHOST TRAIL TRACKING
  // Mencegah silet memendek atau hilang total saat data serial drop/stagnan
  // =========================================================================
  float currentDist = dist(cursorX, cursorY, prevX, prevY);
  
  // Jika koordinat diam/tersangkut di sudut atau tengah, suntikkan pergeseran mikro palsu (0.1 piksel)
  if (currentDist < 0.2) {
    trail.add(new PVector(cursorX + random(-0.1, 0.1), cursorY + random(-0.1, 0.1)));
  } else {
    trail.add(new PVector(cursorX, cursorY));
  }
  
  // Mengunci panjang silet konstan 15 titik koordinat agar tidak membeku
  if (trail.size() > 15) { 
    trail.remove(0); 
  }

  // REPRODUKSI LATAR BELAKANG: PAPAN TALENAN KAYU COKELAT TUA BERTEKSTUR GARIS SERAT ASLI
  background(115, 65, 40); 
  stroke(80, 45, 25); strokeWeight(6);
  for (int i = 0; i < width; i += 45) line(i, 0, i, height); 
  stroke(80, 45, 25, 120); strokeWeight(2.5);
  for (int i = 0; i < height; i += 90) line(-100, i, width + 100, i); 
  
  // Ornamen siluet daun hijau dojo kebun rimbun
  noStroke(); fill(30, 100, 40, 95); 
  pushMatrix(); translate(120, 40); rotate(0.12); ellipse(0, 0, 280, 95); popMatrix();
  pushMatrix(); translate(width-120, 50); rotate(-0.18); ellipse(0, 0, 300, 105); popMatrix();

  // Merender noda cairan jus pekat di atas talenan
  for (int i = juiceStains.size() - 1; i >= 0; i--) {
    JuiceStain js = juiceStains.get(i); js.display();
    if (js.alpha <= 0) juiceStains.remove(i);
  }

  speedMultiplier = constrain(1.0 + (score * 0.003) + (gameTime * 0.0001), 1.0, 1.5); 
  currentGravity = baseGravity * speedMultiplier;
  spawnInterval = max(30, 55 - (speedMultiplier * 6)); 

  if (!gameOver) {
    gameTime++; spawnTimer++;
    if (spawnTimer > spawnInterval) { fruits.add(new Fruit(speedMultiplier, gameTime)); spawnTimer = 0; }
    
    // Pembaruan dan Deteksi Tebasan Buah
    for (int i = fruits.size() - 1; i >= 0; i--) {
      Fruit f = fruits.get(i); f.update(currentGravity); f.display();
      
      float distance = dist(cursorX, cursorY, f.x, f.y);
      if (distance < f.size * 0.65) { 
        if (f.type == 7) { 
          gameOver = true; causeOfGameOver = "MENABRAK BOM HITAM!";
          flashes.add(new SliceFlash(f.x, f.y, color(255, 60, 0))); 
          for (int p = 0; p < 35; p++) particles.add(new Particle(f.x, f.y, color(random(50,80)), random(-8,8), random(-9,4)));
        } 
        else { 
          score += 10;
          flashes.add(new SliceFlash(f.x, f.y, color(255, 255, 255))); // Efek kilat silet menyala
          
          for(int s=0; s<4; s++) juiceStains.add(new JuiceStain(f.x + random(-25,25), f.y + random(-25,25), f.juiceColor, f.size));
          for (int p = 0; p < 25; p++) particles.add(new Particle(f.x, f.y, f.juiceColor, random(-6,6), random(-7,3)));
          
          slicedHalves.add(new SlicedHalf(f.x, f.y, -3.2 * speedMultiplier, f.vy * 0.4, f.size, f.type, true, f.angle));
          slicedHalves.add(new SlicedHalf(f.x, f.y, 3.2 * speedMultiplier, f.vy * 0.4, f.size, f.type, false, f.angle));
        }
        fruits.remove(i); 
      } else if (f.y > height + f.size * 2) fruits.remove(i);
    }
    for (int i = slicedHalves.size() - 1; i >= 0; i--) {
      SlicedHalf sh = slicedHalves.get(i); sh.update(currentGravity); sh.display();
      if (sh.y > height + sh.size * 2) slicedHalves.remove(i);
    }
    for (int i = particles.size() - 1; i >= 0; i--) {
      Particle p = particles.get(i); p.update(); p.display();
      if (p.alpha <= 0) particles.remove(i);
    }
    for (int i = flashes.size() - 1; i >= 0; i--) {
      SliceFlash sf = flashes.get(i); sf.update(); sf.display();
      if (sf.alpha <= 0) flashes.remove(i);
    }
    
    // =========================================================================
    // RENDERING SILET GEOMETRI PADAT MURNI REALISTIS (QUAD_STRIP TEBAL NEON)
    // =========================================================================
    if (trail.size() > 2) {
      noStroke();
      beginShape(QUAD_STRIP); // Layer Sinar Neon Biru Muda
      for (int i = 1; i < trail.size(); i++) {
        PVector p1 = trail.get(i-1), p2 = trail.get(i);
        float alpha = map(i, 0, trail.size(), 20, 160), w = map(i, 0, trail.size(), 1, 14); 
        float angle = atan2(p2.y - p1.y, p2.x - p1.x) + HALF_PI;
        fill(140, 220, 255, alpha);
        vertex(p2.x + cos(angle) * w * 1.5, p2.y + sin(angle) * w * 1.5);
        vertex(p2.x - cos(angle) * w * 1.5, p2.y - sin(angle) * w * 1.5);
      }
      endShape();
      beginShape(QUAD_STRIP); // Layer Inti Bilah Silet Putih Logam Padat
      for (int i = 1; i < trail.size(); i++) {
        PVector p1 = trail.get(i-1), p2 = trail.get(i);
        float alpha = map(i, 0, trail.size(), 40, 255), w = map(i, 0, trail.size(), 0.5, 9); 
        float angle = atan2(p2.y - p1.y, p2.x - p1.x) + HALF_PI;
        fill(255, 255, 255, alpha);
        vertex(p2.x + cos(angle) * w, p2.y + sin(angle) * w);
        vertex(p2.x - cos(angle) * w, p2.y - sin(angle) * w);
      }
      endShape();
    }
    
    textSize(38); fill(255, 165, 0); textAlign(LEFT, TOP);
    text("🍉 SCORE: " + score, 40, 40);
    textSize(32); fill(255, 235, 160); textAlign(RIGHT, TOP);
    text("⏱️ TIME: " + floor(gameTime / 60.0) + "s", width - 40, 40);
    
  } else {
    // LAYAR MENU AKHIR GAME OVER
    trail.clear(); fruits.clear(); particles.clear(); slicedHalves.clear(); flashes.clear();
    textAlign(CENTER, CENTER); textSize(55); fill(240, 60, 60); text("GAME OVER", width/2, height/2 - 120);
    textSize(24); fill(220, 180, 180); text(causeOfGameOver, width/2, height/2 - 70);
    textSize(32); fill(245, 240, 230); text("Total Skor Tebasan Silet: " + score, width/2, height/2 - 15);

    rectMode(CENTER);
    if (cursorX > width/2 - 170 - 100 && cursorX < width/2 - 170 + 100 && cursorY > height/2 + 110 - 25 && cursorY < height/2 + 110 + 25) fill(46, 175, 87); else fill(34, 139, 34);
    stroke(255); rect(width/2 - 170, height/2 + 110, 200, 50, 10);
    fill(255); textSize(20); text("MAIN LAGI (R)", width/2 - 170, height/2 + 108);

    if (cursorX > width/2 + 170 - 100 && cursorX < width/2 + 170 + 100 && cursorY > height/2 + 110 - 25 && cursorY < height/2 + 110 + 25) fill(220, 50, 50); else fill(160, 20, 20);
    rect(width/2 + 170, height/2 + 110, 200, 50, 10);
    fill(255); textSize(20); text("KELUAR GAME", width/2 + 170, height/2 + 108);
    rectMode(CORNER); fill(255); stroke(0); ellipse(cursorX, cursorY, 12, 12);
  }
}

void keyPressed() { if (gameOver && (key == 'r' || key == 'R')) resetGame(); }
void mousePressed() {
  if (gameOver) {
    if (mouseX > width/2 - 170 - 100 && mouseX < width/2 - 170 + 100 && mouseY > height/2 + 110 - 25 && mouseY < height/2 + 110 + 25) resetGame();
    if (mouseX > width/2 + 170 - 100 && mouseX < width/2 + 170 + 100 && mouseY > height/2 + 110 - 25 && mouseY < height/2 + 110 + 25) exit();
  }
}
void resetGame() { score = 0; gameTime = 0; speedMultiplier = 1.0; spawnTimer = 0; gameOver = false; juiceStains.clear(); }

// =========================================================================
// OBJECT CLASS DEFINITIONS & VECTOR RENDERING PIPELINE
// =========================================================================

class Fruit {
  float x, y, vx, vy, size, angle, spinSpeed; int type; color juiceColor; 

  Fruit(float sm, int gt) {
    x = random(180, width - 180); y = height + 50;
    vx = random(-1.3, 1.3) * sm; vy = random(-14.0, -11.5) * (1.0 + (sm - 1.0) * 0.3); size = random(95, 115); 
    if (gt >= 900 && random(1.0) < 0.22) { type = 7; juiceColor = color(0); } else { type = int(random(4)); } 
    angle = random(TWO_PI); spinSpeed = random(-0.03, 0.03) * sm; 
    if (type == 0) juiceColor = color(225, 20, 50);       
    else if (type == 1) juiceColor = color(50, 205, 50);   
    else if (type == 2) juiceColor = color(235, 30, 35);   
    else if (type == 3) juiceColor = color(255, 140, 0);   
  }
  void update(float g) { vy += g; x += vx; y += vy; angle += spinSpeed; }
  void display() { pushMatrix(); translate(x, y); rotate(angle); drawFruitLayeredHD(type, size, 0, TWO_PI); popMatrix(); }
}

class SlicedHalf {
  float x, y, vx, vy, size, angle, spinSpeed; int type; boolean isLeft;
  SlicedHalf(float sx, float sy, float svx, float svy, float sSize, int sType, boolean leftHalf, float initAngle) {
    x = sx; y = sy; vx = svx; vy = svy; size = sSize; type = sType; isLeft = leftHalf; angle = initAngle; spinSpeed = isLeft ? -0.06 : 0.06;
  }
  void update(float g) { vy += g; x += vx; y += vy; angle += spinSpeed; }
  void display() { pushMatrix(); translate(x, y); rotate(angle); if (isLeft) drawFruitLayeredHD(type, size, HALF_PI, HALF_PI + PI); else drawFruitLayeredHD(type, size, -HALF_PI, HALF_PI); popMatrix(); }
}

class JuiceStain {
  float x, y, size, alpha; color c;
  JuiceStain(float sx, float sy, color sc, float fSize) { x = sx; y = sy; c = sc; size = random(fSize*0.5, fSize * 0.9); alpha = 160; }
  void display() { noStroke(); fill(c, alpha); ellipse(x, y, size, size * 0.8); alpha -= 0.5; }
}

void drawFruitLayeredHD(int type, float s, float sa, float ea) {
  noStroke(); float radius = s / 2.0;
  if (type == 0) { // SEMANGKA MERAH BERBIJI
    drawHighDefArc(0, 0, radius, color(24, 90, 34), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.94, color(40, 150, 55), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.88, color(245, 245, 220), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.82, color(215, 25, 45), sa, ea); 
    fill(35);
    if (sa == 0 || sa == HALF_PI) { ellipse(-radius*0.4, -radius*0.3, 6, 4); ellipse(-radius*0.3, radius*0.4, 4, 6); }
    if (ea == TWO_PI || ea == HALF_PI + PI) { ellipse(radius*0.4, radius*0.3, 6, 4); ellipse(radius*0.3, -radius*0.4, 4, 6); }
    ellipse(0, radius*0.45, 4, 6);
  } else if (type == 1) { // JERUK NIPIS HIJAU BERBULIR
    drawHighDefArc(0, 0, radius, color(34, 110, 34), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.93, color(255, 255, 230), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.86, color(50, 185, 50), sa, ea); 
    stroke(255, 255, 240, 180); strokeVerticalFix(sa, ea, radius * 0.84);
    noStroke(); fill(255, 255, 240); ellipse(0, 0, 8, 8); 
  } else if (type == 2) { // APEL MERAH GLOSSY
    drawHighDefArc(0, 0, radius, color(145, 10, 15), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.9, color(225, 25, 30), sa, ea); 
    fill(255, 255, 255, 180); ellipse(-radius*0.3, -radius*0.3, radius*0.4, radius*0.2); 
  } else if (type == 3) { // JERUK MANIS
    drawHighDefArc(0, 0, radius, color(210, 85, 0), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.94, color(255, 245, 200), sa, ea);
    drawHighDefArc(0, 0, radius * 0.88, color(255, 135, 10), sa, ea);
    stroke(255, 245, 200, 150); strokeVerticalFix(sa, ea, radius * 0.86);
    noStroke(); fill(255); ellipse(0, 0, 6, 6);
  } else if (type == 7) { // BOM HITAM BERGARIS SILANG "X"
    drawHighDefArc(0, 0, radius, color(35), sa, ea); 
    drawHighDefArc(0, 0, radius * 0.85, color(75), sa, ea); 
    stroke(130, 95, 45); strokeWeight(3.5);
    if (sa == 0 || sa == -HALF_PI) line(0, -radius, 6, -radius - 14); 
    noStroke(); fill(255, 185, 0); if (sa == 0 || sa == -HALF_PI) ellipse(6, -radius - 16, 12, 12); 
    fill(255, 60, 0); ellipse(6, -radius - 16, 6, 6);
    stroke(220, 20, 20); strokeWeight(8);
    if (sa == 0 && ea == TWO_PI) { line(-radius*0.4, -radius*0.4, radius*0.4, radius*0.4); line(radius*0.4, -radius*0.4, -radius*0.4, radius*0.4); } 
    else if (sa == HALF_PI) { line(-radius*0.4, -radius*0.4, 0, 0); line(0, 0, -radius*0.4, radius*0.4); } 
    else if (sa == -HALF_PI) { line(0, 0, radius*0.4, radius*0.4); line(radius*0.4, -radius*0.4, 0, 0); }
  }
}

void drawHighDefArc(float cx, float cy, float r, color c, float startA, float endAngle) {
  fill(c); beginShape();
  if (startA != 0 || endAngle != TWO_PI) vertex(cx, cy); 
  int segments = 64; 
  for (int i = 0; i <= segments; i++) {
    float angle = map(i, 0, segments, startA, endAngle);
    vertex(cx + cos(angle) * r, cy + sin(angle) * r);
  }
  endShape(CLOSE);
}

void strokeVerticalFix(float sa, float ea, float r) {
  for (float a = 0; a < TWO_PI; a += PI/4) { if (a >= sa && a <= ea) line(0, 0, cos(a) * r, sin(a) * r); }
}

class SliceFlash {
  float x, y, len, alpha; color flashColor;
  SliceFlash(float sx, float sy, color c) { x = sx; y = sy; len = 5; alpha = 255; flashColor = c; }
  void update() { len += 28; alpha -= 26; } 
  void display() {
    stroke(flashColor, alpha); strokeWeight(9); line(x - len, y - len * 0.3, x + len, y + len * 0.3); 
    stroke(255, 255, 255, alpha * 0.9); strokeWeight(4); line(x - len * 0.5, y + len * 0.4, x + len * 0.6, y - len * 0.3);
    noStroke(); fill(255, 255, 255, alpha); ellipse(x, y, len * 0.4, len * 0.4); 
  }
}

class Particle {
  float x, y, vx, vy, size, alpha; color pColor;
  Particle(float startX, float startY, color fruitJuiceColor, float svx, float svy) { x = startX; y = startY; vx = svx; vy = svy; size = random(6, 12); alpha = 255; pColor = fruitJuiceColor; }
  void update() { x += vx; y += vy; vy += 0.22; alpha -= 5.0; }
  void display() { noStroke(); fill(pColor, alpha); ellipse(x, y, size, size); }
}
