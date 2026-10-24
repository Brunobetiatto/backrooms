// BACKROOMS: Escape from the Nerdolas — v1.1
// Processing 4 (P3D) + Minim. Assets: carpet.jpg wall.jpg roof.jpg menu.png ambiente.mp3
//   gabriel / vitor / gustavo / isa / gaias / luca (.jpg + .mp3)
//   optional: data/pucpr.png (any photo of the PUCPR campus, blurred automatically)
//   optional: data/flashlight.mp3
// Save files: best.txt, best_fuga.txt, achievements.txt, progress.txt

import ddf.minim.*;
import ddf.minim.ugens.*;
import com.jogamp.newt.opengl.GLWindow;

// ---------------- tuning knobs ----------------
int GRID = 25;                     // maze size in cells (odd) — changes per mode
final int MAX_GRID     = 37;
final int GRID_ENDLESS = 25, GRID_DAY = 31, GRID_FINAL = 37;
final float CELL         = 400;    // size of one cell in world units
final float WALL_H       = 420;    // ceiling height
final float EYE_H        = 230;    // camera height
final float PLAYER_R     = 60;     // player collision radius
final float WALK_SPEED   = 260;    // units per second
final float SPRINT_SPEED = 440;
final float STAMINA_MAX  = 2.5;    // seconds of sprint
final float ENEMY_START  = 190;
final float ENEMY_MAX    = 400;
final float ENEMY_RAMP   = 3.5;    // enemy speed gained per second survived
final float GRACE_TIME   = 3;      // seconds before the enemies start hunting
final float KILL_DIST    = 110;
final float MOUSE_SENS   = 0.0025;

// ---------------- visuals ----------------
final float FOG_DIST      = 2600;
final float EXPOSURE_BASE = 0.6;
final boolean VOLUMETRIC  = true;
final float VHS_AMOUNT    = 0.15;
final float HANDHELD      = 0.5;
final int   OUTLETS       = 26;    // wall props (scaled with map size)
final int   VENTS         = 12;
final float LENS_FISHEYE  = 0.2;   // the player's vision (world + hands): barrel distortion
final float LENS_GRAIN    = 0.022; // film grain on the player's vision (very subtle)
final float LENS_SOFT     = 0.6;   // grainy micro-blur, a bit softer toward the edges (very subtle)
final float OSD_FISHEYE   = 0.04;  // the whole camcorder image, on-screen text included
final int   MAP_FLOATS    = (MAX_GRID * MAX_GRID + 3) / 4;   // 4 cells packed per float
final int   MAP_VEC4      = (MAP_FLOATS + 3) / 4;
final float[] PACK        = {1, 17, 289, 4913};             // base-17 packing for the shader grid

// ---------------- player ----------------
final float CROUCH_SPEED = 150;
final float CROUCH_EYE   = 150;
final float PEEK_ANGLE   = 0.36;   // how far the torso tilts when leaning (radians, ~20 deg)
final float PEEK_PIVOT   = 0.45;   // the lean pivots at the hips: this fraction of the eye height
final float PEEK_MIN     = 28;     // less room than this beside you = no lean
final float PEEK_HEAD_R  = 25;     // the head's clearance from walls while leaning
final float PEEK_WALL    = 300;    // the wall in front must be this close to count as a corner
final float PEEK_VIEW_GAIN = 250;  // leaning must open the view at least this much further
final float PEEK_ROLL    = radians(45);   // head tilt at full lean (the view rolls 0 -> 45 deg)

// ---------------- modes ----------------
final int ENDLESS = 0, FUGA = 1;
final int DAYS = 6, FINAL_DAY = 6;               // days 0..5 = one nerdola each, day 6 = VS. 6
final int RECUP_DAY = 7;                         // RECUPERAÇÃO uses the next "day" slot
final int[] DAY_ORDER = {0, 4, 2, 1, 3, 5};      // Gabriel, Gaias, Gustavo, Vitor, Isa, Luca
final int CERTS_PER_DAY  = 3;                    // 2 open the exit + 1 extra
final int CERTS_TO_EXIT  = 2;
final int CERTS_FINAL    = 3;                    // VS. 6: all three needed, no hours
final int HOURS_PER_CERT = 2;
final float CERT_SPEEDUP = 30;
final int ARROWS_PER_CERT = 2;
final int ARROWS_TO_EXIT  = 3;
final float MULTI_SPEED   = 0.85;                // all-six modes: each one is a bit slower

// ---------------- the nerdolas ----------------
final String[] NAMES = {"Gabriel", "Vitor", "Gustavo", "Isa", "Gaias", "Luca"};
final int T_GABRIEL = 0, T_VITOR = 1, T_GUSTAVO = 2, T_ISA = 3, T_GAIAS = 4, T_LUCA = 5;
final String[] NICKS = {"O ansioso", "O prodígio", "O fonoaudiólogo", "A stalker", "O teimoso", "O imprevisível"};
final String[] TRAITS = {
  "18% mais rápido e dá botes mais fortes, mas te ouve menos.",
  "Prevê para onde você está correndo e te corta no caminho. Te rastreia 2,5x mais tempo depois de te perder de vista, e lembra mais.",
  "Ouve seus passos 70% mais longe, mas a voz dele é mais alta, então você também o ouve chegando.",
  "Silenciosa até estar a 3 salas de você, e não apaga as luzes. Você não recebe nenhum aviso.",
  "Enxerga 30% mais longe, o taser só o atordoa pela metade do tempo e ele procura por você o dobro do tempo.",
  "A cada 14-24 s ele some e reaparece de 4 a 7 salas de você, sempre fora da sua linha de visão."
};
final float[] SPEED_MUL  = {1.18, 1, 1, 1, 1, 1};
final float[] LUNGE_MUL  = {1.25, 1, 1, 1, 1, 1};
final float[] HEAR_MUL   = {0.6, 1, 1.7, 1, 1, 1};
final float[] SIGHT_MUL  = {1, 1, 1, 1, 1.3, 1};
final float[] MEM_MUL    = {1, 2.5, 1, 1, 1, 1};
final float[] SENSE_MUL  = {1, 0.5, 1, 1, 1, 1};
final float[] STUN_MUL   = {1, 1, 1, 1, 0.5, 1};
final float[] SEARCH_MUL = {1, 1, 1, 1, 2, 1};

// ---------------- drops ----------------
final int COXINHA = 0, SALADA = 1, LAGRIMAS = 2, CESTA = 3, TASER = 4, MONSTER = 5, LATA = 6;
final String[] ITEM_NAMES  = {"Coxinha da Lapa", "Salada de Frutas do James", "Lágrimas de Andrey Cabral", "Cesta Básica do Frank", "Taser",
                              "Monster Ultra Zero", "Lata Vazia"};
final String[] ITEM_DESC   = {
  "Corrida infinita por 8 segundos.",
  "25% mais rápido por 15 segundos.",
  "Invisível por 10 segundos: eles não te veem e te ouvem pela metade.",
  "Fôlego em dobro e regeneração triplicada por 30 segundos.",
  "Um disparo. Atordoa o nerdola na mira e faz ele te perder.",
  "Pilhado por 10 segundos: você vê os nerdolas através das paredes. Sobra a lata.",
  "Arremesse e faça barulho: os nerdolas que ouvirem vão checar onde ela caiu."
};
final String[] ITEM_KEYS   = {"1", "2", "3", "4", "Q", "5", "G"};
final boolean[] ITEM_DRINK = {false, false, true, false, false, true, false};
final int[]   USE_MS       = {1500, 1700, 1300, 2000, 0, 1600, 0};
final int[]   BUFF_MS      = {8000, 15000, 10000, 30000, 0, 10000, 0};
final int[]   DROP_BAG     = {3, 3, 3, 3, 1, 2, 0};    // per shuffled bag: coxinha, salada, lágrimas, cesta, taser, monster (cans only come from drinking)
final float   TASER_UNLOCK = 30;                 // no tasers in the first seconds of a run
final float   DROP_ROTATE  = 20;                 // every N seconds a far-away drop is swapped
final int     DROPS        = 7;                  // on a 25x25 map (scaled with map size)
final int     MAX_STACK    = 3;
final float   TASER_RANGE  = CELL * 3.5;
final int     STUN_MS      = 3500;
final int     CONFUSE_MS   = 6000;

// ---------------- monster + empty can ----------------
final float XRAY_ALPHA  = 0.55;       // the nerdolas' ghost through the walls while PILHADO
final float CAN_SCALE   = 0.4;        // the thrown can (the crushed model is 54 tall)
final float CAN_FLOOR   = 27 * CAN_SCALE;   // half its crushed height: resting height when it lands flat
final float CAN_SPEED   = 1300;       // throw speed, units/s
final float CAN_LOFT    = 250;        // a bit of upward toss
final float GRAVITY     = 1320;
final float CAN_HEAR    = 8;          // rooms a loud clank carries (x each nerdola's hearing): louder than a sprint
final int   MAX_CANS    = 8;
final int   START_CANS  = 2;          // empty cans you start every run with

// ---------------- the blessing of Cabral ----------------
final int   SECRETS     = 3;          // secret passages per map (one hides the pizza while this phase's is uneaten)
final int   SECRET_NEAR = 14;         // prefer dead ends within this many rooms of the start
final float PIZZA_BONUS = 0.08;       // Pizza do Papponi: +8% max stamina each, forever
final int   PHASES      = 9;          // POLIWEEK days 0-5, VS. 6, RECUPERAÇÃO, ENDLESS: one pizza each
final float REVEAL_TIME = 1.0;        // seconds of flashlight on the wall to open it

// ---------------- wall writings ----------------
final String[] WALL_MSGS = {
  "CADE MINHAS\nHORAS CABRAL",
  "O FRANK FEZ\nELE TRANCAR...",
  "O QUE ACONTECEU\nCOM O GUSTAVO DO MAL",
  "NAO FALE SOBRE\nOUTER WILDS COM O VITOR",
  "ILUMINE A ESCURIDAO\nE RECEBA A BENCAO\nDO CABRAL"
};
final int CABRAL_MSG = 4;           // placed once in every run, near the start
final int DECALS = 9;

// ---------------- nextbot AI ----------------
final float SIGHT_CELLS  = 10;     // seen from this far when you're fully lit
final float SIGHT_FLASH  = 14;     // ...with your flashlight on (you're a beacon)
final float SIGHT_DARK   = 0.2;    // in pitch dark, sight shrinks to 20% (2 rooms; crouched and still: under 1)
final float VIEW_HALF    = radians(60);   // they only see in a 120-degree cone ahead of them
final float TURN_RATE    = 5;      // how fast they turn their head (rad/s)
final float DEADEND_DARK = 0.6;    // chance a dead end has no lamp: hiding spots
final float LAMP_REACH   = 1.2;    // a lamp lights its own room well and the next ones only a little (rooms)
final float HEAR_SPRINT  = 7;
final float HEAR_WALK    = 2.5;
final float TOUCH_CELLS        = 1.2;    // proximity bubble, normal
final float CROUCH_TOUCH       = 0.5;    // ...crouched
final float GHOST_TOUCH        = 0.4;    // ...invisible (practically touching)
final float GHOST_HEAR         = 0.35;   // invisible: heard from 35% of the normal range
final float CROUCH_SIGHT       = 0.6;    // crouch-walking: seen from 60% of the distance
final float CROUCH_STILL_SIGHT = 0.42;   // crouched and still: 42%
final float MEMORY       = 1.2;
final float SEARCH_WAIT  = 2.5;
final float SENSE_TIME   = 18;
final int   LOCK_MS      = 350;
final int   LUNGE_MS     = 1500;
final float LUNGE_MULT   = 1.3;
final float FRENZY_TIME  = 4;
final float FRENZY_MULT  = 1.12;
final int   WANDER = 0, SEARCH = 1, CHASE = 2;

// ---------------- achievements ----------------
final String[] ACH_NAME = {
  "Primeiros Passos", "Estagiário dos Backrooms", "Efetivado", "Lanchinho da Lapa", "Cardápio Completo",
  "Acumulador", "Saqueador", "Choque de Realidade", "Por um Fio", "Fujão",
  "Maratonista", "Breu", "À Queima-Roupa", "Arqueólogo", "Jejum",
  "Formado", "Speedrun Acadêmico", "Sem Cola",
  "Só Taser", "Dieta da Lapa", "Pacifista", "Lágrimas de Crocodilo", "Estoque Cheio",
  "Panela de Pressão", "Turista", "Sem Pressa",
  "Bolsista", "Hora Extra", "Semana Completa", "36 Horas",
  "Aprovado"
};
final String[] ACH_DESC = {
  "Sobreviva 1 minuto",
  "Sobreviva 3 minutos",
  "Sobreviva 7 minutos",
  "Coma 3 Coxinhas da Lapa na mesma partida",
  "Use os 4 consumíveis nos primeiros 2 minutos",
  "Colete 6 itens em menos de 45 segundos",
  "Colete 25 itens na mesma partida",
  "Atordoe nerdolas 3 vezes na mesma partida",
  "Deixe um passar a 1 sala de você, agachado, sem te ver",
  "Escape de 8 perseguições na mesma partida",
  "Corra por 90 segundos no total",
  "Fique 2 minutos seguidos com a lanterna desligada",
  "Acerte o taser a menos de meia sala",
  "Leia todas as mensagens nas paredes",
  "Sobreviva 5 minutos sem consumir nada",
  "Vença um dia da POLIWEEK",
  "Vença um dia da POLIWEEK em menos de 3 minutos",
  "Vença um dia da POLIWEEK sem nunca ser visto",
  "Colete 3 tasers e nenhum outro item na mesma partida",
  "Sobreviva 3 min consumindo só coxinhas (pelo menos 3)",
  "Sobreviva 5 min com um taser no bolso sem usar nenhum",
  "Escape de uma perseguição enquanto estiver invisível",
  "Tenha 3 de cada consumível ao mesmo tempo",
  "Seja perseguido por 30 segundos seguidos sem morrer",
  "Visite 80% das salas do mapa",
  "Sobreviva 2 minutos sem correr nenhuma vez",
  "Vença um dia da POLIWEEK sem consumir nada",
  "Vença um dia da POLIWEEK depois de ser visto 5 vezes",
  "Vença o Dia 7 (VS. 6) da POLIWEEK",
  "Valide 36h/36h de horas complementares",
  "Vença a RECUPERAÇÃO"
};
final int[] ACH_MODE = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
                        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1};
boolean[] achUnlocked = new boolean[ACH_NAME.length];
ArrayList<Integer> runAch = new ArrayList<Integer>();
ArrayList<Integer> toastQueue = new ArrayList<Integer>();
int toastStart;

final int MENU = 0, PLAYING = 1, DEAD = 2, WIN = 3, EMAIL = 4;
int state = MENU;
int gameMode = FUGA;

final int[][] DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
final String[] MESES = {"JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"};
final String[] MENU_OPTS = {"POLIWEEK", "ENDLESS", "RECUPERAÇÃO", "CATÁLOGO", "CONQUISTAS", "SAIR"};
final String[] CAT_TABS = {"NERDOLAS", "PICHAÇÕES", "ITENS", "ESTATÍSTICAS"};

PImage[] faces = new PImage[NAMES.length];
AudioPlayer[] voices = new AudioPlayer[NAMES.length];

// ---------------- progress (saved) ----------------
boolean[] dayBeaten = new boolean[8];
int[] dayCerts = new int[8];
boolean finalBeaten, endlessUnlocked, recupUnlocked;
boolean emailFirst;
boolean[] msgSeen = new boolean[WALL_MSGS.length];
boolean[] itemSeen = new boolean[ITEM_NAMES.length];
int totalRuns, totalDeaths, totalItems, totalConsumed, totalStuns, totalEscapes, totalCerts, totalWins;
float totalTime;

// ---------------- audio ----------------
Minim minim;
AudioPlayer ambience;
AudioOutput out;
Oscil hum, hum2, heart;
Multiplier stepAmp, breathAmp, staticAmp;
Oscil[] sting = new Oscil[3];
final float[] STING_F = {196.0, 207.65, 277.18};
Oscil boom, screech;
Oscil drone1, drone2, kick;
MoogFilter droneLP;
Multiplier tickAmp;
Oscil achOsc;
float achT = -1;
float stingT = -1;
int lastStingMs = -99999;
float chaseLvl, chaseBeat, kickEnv, tickEnv;
int lastBeatStep;
AudioSample flashSnd;

// ---------------- graphics ----------------
PImage carpet, wall, roof, menuImg, panelTex, certTex, exitTex, staticImg, outletTex, ventTex, pucprBg;
PImage[] itemTex = new PImage[ITEM_NAMES.length];
PImage[] graffiti = new PImage[WALL_MSGS.length];
PShape level;
PShader world, post, lens;
GLWindow win;
PFont fontBig, fontUI, fontMono, fontGraffiti, fontHud, fontMail;
float exposureAdapt = 1, camGain = 0;
float camX, camY, camZ, camDX, camDY, camDZ;

boolean[][] solid;
int[][] flow;
int flowI = -1, flowJ = -1;
int[][] lampType;
float[][] lampP;
float[] mapU = new float[MAP_VEC4 * 4];
float humLevel, localLight;
float playerExpo;                  // how lit you are by the fixed lamps (0 = pitch dark, 1 = fully lit)

class Drop {
  float x, y;
  int type;
  Drop(float x, float y, int type) {
    this.x = x;
    this.y = y;
    this.type = type;
  }
}

// a thrown empty can
class Can {
  float x, y, z, vx, vy, vz;
  float heading, tumble, tumbleV;
  boolean rest;
  int lastClank, lastAlert;
}

ArrayList<Can> cans = new ArrayList<Can>();
PShape canModel;
AudioSample[] clanks;

// a dark dead end hiding a passage: shine your flashlight on its far wall
class Secret {
  int di, dj;          // the dead end
  int wi, wj;          // the wall cell that opens into the hidden nook
  float light;         // how long it's been in your beam
  boolean open, pizza, eaten;
  Decal mark;          // Cabral's sun painted on the wall: in the dark it only shows under the flashlight
}

ArrayList<Secret> secrets = new ArrayList<Secret>();
boolean[] pizzaGot = new boolean[PHASES];   // saved: which phases' pizza you've eaten
PShape pizzaModel;
PImage cabralMark;

class Particle {
  float x, y, vx, vy, life, sz;
  int col;
  Particle(float x, float y, float vx, float vy, int col, float sz) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.col = col;
    this.sz = sz;
    life = 1;
  }
}

class Decal {
  float cx, cy, z, nx, ny, w, h;
  int msg;
  PImage tex;
}

class Cert {
  int i, j, di, dj;
  float x, y, z;
}

class Arrow {
  float cx, cy, z, nx, ny;
  float size, tilt;
  boolean flip;
}

// one hunting nerdola
class Enemy {
  int ch;
  PVector pos = new PVector(), lastSeen = new PVector();
  int ai = WANDER;
  boolean sees;
  float lostTimer, searchTimer, senseTimer, chaseTime;
  int lockUntil, lungeUntil, screamUntil, stunUntil, confusedUntil, nextTeleport;
  int[][] goalFlow;
  int goalI = -1, goalJ = -1;
  float sx, sy;
  float unseenFor;        // Luca: how long you haven't been looking at him
  float lastVX, lastVY;   // your velocity at the moment it last detected you
  boolean inFront;
  float face = random(TWO_PI);   // where it's looking
  float scanBase, scanT;         // looking around while it stands still
  boolean wasMoving;
}

ArrayList<Enemy> enemies = new ArrayList<Enemy>();
Enemy nearE, boltEnemy;
float nearD, threatD;
boolean anyChase;
int killerCh, winFaceCh;
int runDay, runEntry;
float graceTime;
float pvx, pvy;                    // player velocity (for Vitor's predictions)

ArrayList<Drop> drops = new ArrayList<Drop>();
ArrayList<Particle> parts = new ArrayList<Particle>();
ArrayList<Decal> decals = new ArrayList<Decal>();
ArrayList<Cert> certs = new ArrayList<Cert>();
ArrayList<Arrow> arrows = new ArrayList<Arrow>();
PImage arrowTex;
int nearCert = -1;

int[] inv = new int[ITEM_NAMES.length];
int useType = -1, useStart;
float chewTimer;
int energyUntil, swiftUntil, ghostUntil, fedUntil, pilhadoUntil;
int lastThrow;
int fireUntil;
boolean taserHit;
float tipSX, tipSY, biteSX, biteSY;
int itemsUsed, stuns;

// POLIWEEK
int certsTaken, certsPlaced, certsRequired;
boolean exitOpen;
int exitI, exitJ, exitDI, exitDJ;
float bestFuga = 0;
boolean newRecordFuga;
int winMs, emailMs;
boolean emailPending, emailSuccess;
int winHoursBefore;

// run stats (achievements)
int itemsCollected, chasesEscaped;
float sprintTime, darkTime;
boolean[] usedType = new boolean[ITEM_NAMES.length];
boolean[] readMsg = new boolean[WALL_MSGS.length];
boolean everSpotted, runCounted;
ArrayList<Integer> pickupTimes = new ArrayList<Integer>();
int[] collectedType = new int[ITEM_NAMES.length];
int[] usedCount = new int[ITEM_NAMES.length];
int tasersFired, chasesStarted, visitedCount, openCells;
float darkStreak, dropTimer;
boolean[][] visited;
ArrayList<Integer> dropBag = new ArrayList<Integer>();

PVector player = new PVector();
float spotFlash;

// the Eye
float eyeOpen, eyeLX, eyeLY;
int blinkUntil, nextBlink;

float yaw, pitch, stamina, bobPhase;
float eyeH = EYE_H;
float fov = radians(72), roll;
boolean moving, sprinting, crouching, crouchToggle, exhausted, flashlightOn = true;
int peekSide, peekDir;               // -1 left (Q), 1 right (E), 0 not peeking; peekDir = last side, for the ease-out
float peekAmt;                       // 0..1 how far the head is leaned out
PVector peekOff = new PVector();     // where the eye goes, relative to the body
PVector peekL, peekR;                // corners you could lean around right now (null = none)
float flicker = 1, flickerUntil = 0;
float stepEnv, hbPhase, breathPhase, staticBurst;
float frameDt;
int lastStep;
int startMs, deathMs, lastMs, skipMouse, msgUntil;

// ---------------- pause + sound settings ----------------
final String[] PAUSE_OPTS = {"CONTINUAR", "SOM", "REINICIAR", "MENU PRINCIPAL"};
final String[] VOL_NAMES  = {"GERAL", "AMBIENTE", "EFEITOS", "VOZES"};
final int V_MASTER = 0, V_AMB = 1, V_FX = 2, V_VOICE = 3;
int[] vol = {100, 100, 100, 100};    // percent per channel, saved in settings.txt
boolean paused;
int pauseStart, pauseSel, pausePage;  // page 0 = the menu, 1 = sound
PImage pauseShot;                     // the frozen frame behind the menu
String msg = "";
float survived, best = 0;
boolean newRecord;
boolean kUp, kDown, kLeft, kRight, kSprint, kCrouch;
boolean[] keyDown = new boolean[512];

// menu
int menuPage = 0, menuSel = 0, catTab = 0;
int lineupMode = FUGA, pwSel = 0, enSel = 0;
float lineShift, menuStatic, menuFlicker = 1;
int lastStaticUpd;
int switchMs = -99999, pageSwitchMs = -99999;   // static transitions
int[] twitchUntil = new int[7];
int[] twType = new int[7];
float[] twDx = new float[7], twDy = new float[7], twRot = new float[7];

// =====================================================================
// SHADERS
String[] WORLD_VERT = {
  "#define PROCESSING_TEXTURE_SHADER",
  "uniform mat4 transformMatrix;",
  "uniform mat4 modelviewMatrix;",
  "uniform mat4 texMatrix;",
  "uniform vec3 camPos;",
  "uniform vec3 camRight;",
  "uniform vec3 camUp;",
  "uniform vec3 camDir;",
  "attribute vec4 position;",
  "attribute vec4 color;",
  "attribute vec2 texCoord;",
  "varying vec4 vertColor;",
  "varying vec4 vertTexCoord;",
  "varying vec3 wPos;",
  "varying vec3 ePos;",
  "void main() {",
  "  gl_Position = transformMatrix * position;",
  "  ePos = (modelviewMatrix * position).xyz;",
  "  wPos = camPos + camRight * ePos.x + camUp * ePos.y - camDir * ePos.z;",
  "  vertColor = color;",
  "  vertTexCoord = texMatrix * vec4(texCoord, 1.0, 1.0);",
  "}"
};

String[] WORLD_FRAG = {
  "#define PROCESSING_TEXTURE_SHADER",
  "#ifdef GL_ES",
  "precision highp float;",
  "#endif",
  "uniform sampler2D texture;",
  "uniform vec2 texOffset;",
  "uniform vec3 camPos;",
  "uniform vec3 camDir;",
  "uniform vec4 mapData[" + MAP_VEC4 + "];",
  "uniform float gridSize;",
  "uniform float cellSize;",
  "uniform float wallH;",
  "uniform float lampZ;",
  "uniform float flash;",
  "uniform float glow;",
  "uniform float emissive;",
  "uniform float exposure;",
  "uniform float fogDist;",
  "uniform float volOn;",
  "uniform vec3 fogColor;",
  "varying vec4 vertColor;",
  "varying vec4 vertTexCoord;",
  "varying vec3 wPos;",
  "varying vec3 ePos;",
  "const float PI = 3.14159265;",

  // 4 cells packed per float in base 17: 0 = wall, 1..16 = open with lamp brightness
  "float cellVal(vec2 c) {",
  "  if (c.x < 0.0 || c.y < 0.0 || c.x >= gridSize || c.y >= gridSize) return -1.0;",
  "  float idx = c.y * gridSize + c.x;",
  "  float fi = floor(idx * 0.25 + 0.01);",
  "  float sub = idx - fi * 4.0;",
  "  float q = floor(fi * 0.25 + 0.01);",
  "  float r = fi - q * 4.0;",
  "  vec4 v4 = mapData[int(q)];",
  "  float v = r < 0.5 ? v4.x : (r < 1.5 ? v4.y : (r < 2.5 ? v4.z : v4.w));",
  "  float base = sub < 0.5 ? 1.0 : (sub < 1.5 ? 17.0 : (sub < 2.5 ? 289.0 : 4913.0));",
  "  float hi = floor((v + 0.5) / base);",
  "  float code = hi - 17.0 * floor((hi + 0.5) / 17.0);",
  "  return code < 0.5 ? -1.0 : (code - 1.0) / 15.0;",
  "}",
  "float isOpen(vec2 c) { return cellVal(c) > -0.5 ? 1.0 : 0.0; }",

  "float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }",
  "float vnoise(vec2 p) {",
  "  vec2 i = floor(p);",
  "  vec2 f = fract(p);",
  "  f = f * f * (3.0 - 2.0 * f);",
  "  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);",
  "}",
  "float fbm(vec2 p) { return (vnoise(p) * 0.5 + vnoise(p * 2.03) * 0.25 + vnoise(p * 4.01) * 0.125) / 0.875; }",
  "float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }",
  "vec3 aces(vec3 x) { return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }",

  "vec3 brdf(vec3 N, vec3 V, vec3 L, vec3 Ls, vec3 albedo, float rough, float f0) {",
  "  float NdL = max(dot(N, L), 0.0);",
  "  float NdLs = max(dot(N, Ls), 0.0);",
  "  if (NdL <= 0.0 && NdLs <= 0.0) return vec3(0.0);",
  "  vec3 H = normalize(Ls + V + vec3(0.0, 0.0, 1e-5));",
  "  float NdV = max(dot(N, V), 0.001);",
  "  float NdH = max(dot(N, H), 0.0);",
  "  float VdH = clamp(dot(V, H), 0.0, 1.0);",
  "  float a = rough * rough;",
  "  float a2 = a * a;",
  "  float dd = NdH * NdH * (a2 - 1.0) + 1.0;",
  "  float D = a2 / (PI * dd * dd);",
  "  float k = (rough + 1.0) * (rough + 1.0) / 8.0;",
  "  float G = NdV / (NdV * (1.0 - k) + k) * NdLs / (NdLs * (1.0 - k) + k);",
  "  float F = f0 + (1.0 - f0) * pow(clamp(1.0 - VdH, 0.0, 1.0), 5.0);",
  "  float spec = min(D * G * F / (4.0 * NdV * max(NdLs, 0.001)), 3.0);",
  "  return albedo * (1.0 - F) / PI * NdL + vec3(spec * NdLs);",
  "}",

  "void main() {",
  "  vec4 tex = texture2D(texture, vertTexCoord.st) * vertColor;",
  "  if (tex.a < 0.35) discard;",
  "  vec3 V = camPos - wPos;",
  "  float dist = length(V);",
  "  vec3 Vn = V / max(dist, 0.001);",
  "  vec3 gn = normalize(cross(dFdx(wPos), dFdy(wPos)));",
  "  if (dot(gn, Vn) < 0.0) gn = -gn;",
  "  bool isLevel = emissive < 0.01;",
  "  if (isLevel) {",
  "    vec3 an = abs(gn);",
  "    if (an.z >= an.x && an.z >= an.y) gn = vec3(0.0, 0.0, sign(gn.z));",
  "    else if (an.x >= an.y) gn = vec3(sign(gn.x), 0.0, 0.0);",
  "    else gn = vec3(0.0, sign(gn.y), 0.0);",
  "  }",

  "  vec3 albedo = pow(tex.rgb, vec3(2.2));",
  "  float rough = 0.65;",
  "  float f0 = 0.04;",
  "  float bump = 0.0;",
  "  if (isLevel) {",
  "    if (gn.z > 0.5) {",
  "      float wet = smoothstep(0.60, 0.72, fbm(wPos.xy / 260.0 + 3.7));",
  "      albedo *= (0.85 + 0.3 * fbm(wPos.xy / 700.0)) * mix(1.0, 0.65, wet);",
  "      rough = mix(0.95, 0.42, wet);",
  "      f0 = mix(0.03, 0.05, wet);",
  "      bump = mix(1.4, 0.4, wet);",
  "    } else if (gn.z < -0.5) {",
  "      float s = fbm(wPos.xy / 320.0 + 11.0);",
  "      float ring = smoothstep(0.64, 0.68, s) - smoothstep(0.69, 0.73, s);",
  "      albedo *= mix(vec3(1.0), vec3(0.78, 0.66, 0.48), smoothstep(0.64, 0.74, s) * 0.45 + ring * 0.5);",
  "      rough = 0.9;",
  "      bump = 0.9;",
  "    } else {",
  "      vec2 t2 = vec2(gn.y, -gn.x);",
  "      float along = dot(wPos.xy, t2);",
  "      float grime = 1.0 - smoothstep(0.0, 140.0, wPos.z);",
  "      albedo *= (0.88 + 0.24 * fbm(vec2(along, wPos.z) / 600.0)) * (1.0 - 0.22 * grime);",
  "      rough = 0.75;",
  "      bump = 0.7;",
  "    }",
  "  }",

  "  vec3 n = gn;",
  "  float bumpFade = 1.0 - smoothstep(350.0, 1100.0, dist);",
  "  if (bump > 0.0 && bumpFade > 0.0) {",
  "    vec2 uv = vertTexCoord.st;",
  "    float h0 = lum(texture2D(texture, uv, 1.0).rgb);",
  "    float hx = lum(texture2D(texture, uv + vec2(texOffset.x * 2.0, 0.0), 1.0).rgb);",
  "    float hy = lum(texture2D(texture, uv + vec2(0.0, texOffset.y * 2.0), 1.0).rgb);",
  "    vec3 dp1 = dFdx(wPos);",
  "    vec3 dp2 = dFdy(wPos);",
  "    vec2 duv1 = dFdx(uv);",
  "    vec2 duv2 = dFdy(uv);",
  "    vec3 dp2perp = cross(dp2, gn);",
  "    vec3 dp1perp = cross(gn, dp1);",
  "    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;",
  "    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;",
  "    float im = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-10));",
  "    float s = bump * 2.0 * bumpFade;",
  "    vec3 nts = normalize(vec3((h0 - hx) * s, (h0 - hy) * s, 1.0));",
  "    n = normalize(T * im * nts.x + B * im * nts.y + gn * nts.z);",
  "  }",

  "  vec3 lampCol = vec3(1.0, 0.92, 0.72);",
  "  vec3 direct = vec3(0.0);",
  "  float irr = 0.0;",
  "  vec2 toCam = camPos.xy - wPos.xy;",
  "  vec2 a = wPos.xy + gn.xy * 4.0 + toCam / max(length(toCam), 1.0) * 3.0;",
  "  vec2 cc = floor(a / cellSize);",
  "  float hr = cellSize * 1.5;",
  "  vec3 R = reflect(-Vn, n);",
  "  float ptZ = wallH - 6.0;",
  "  vec2 panelHalf = vec2(cellSize * 0.28, cellSize * 0.14);",
  "  for (int j = -1; j <= 1; j++) {",
  "    for (int i = -1; i <= 1; i++) {",
  "      vec2 d = vec2(float(i), float(j));",
  "      vec2 c = cc + d;",
  "      float p = cellVal(c);",
  "      if (p <= 0.01) continue;",
  "      vec2 b = (c + 0.5) * cellSize;",
  "      float hd = length(b - wPos.xy);",
  "      if (hd >= hr) continue;",
  "      float vis = 1.0;",
  "      if (i != 0 && j != 0) {",
  "        vec2 K = (cc + 0.5 + 0.5 * d) * cellSize;",
  "        vec2 dir = b - a;",
  "        float side = (dir.x * (K.y - a.y) - dir.y * (K.x - a.x)) / max(length(dir), 1.0) * d.x * d.y;",
  "        float pen = 40.0 + 0.5 * length(K - a);",
  "        vis = mix(isOpen(cc + vec2(0.0, d.y)), isOpen(cc + vec2(d.x, 0.0)), smoothstep(-pen, pen, side));",
  "        vis = max(vis, 0.12);",
  "        if (vis <= 0.0) continue;",
  "      }",
  "      vec3 Lp = vec3(b, lampZ) - wPos;",
  "      float dl = length(Lp);",
  "      vec3 L = Lp / dl;",
  "      float w = 1.0 - pow(hd / hr, 4.0);",
  "      float att = (w * w) / (1.0 + dl * dl / (cellSize * cellSize * 0.9));",
  "      vec3 Ls = L;",
  "      if (R.z > 0.01) {",
  "        vec2 hit = wPos.xy + R.xy * ((ptZ - wPos.z) / R.z);",
  "        Ls = normalize(vec3(clamp(hit, b - panelHalf, b + panelHalf), ptZ) - wPos);",
  "      }",
  "      direct += brdf(n, Vn, L, Ls, albedo, rough, f0) * lampCol * (1.15 * PI * p * att * vis);",
  "      irr += p * att * vis;",
  "    }",
  "  }",

  "  vec3 bounceCol = vec3(0.95, 0.78, 0.52);",
  "  vec3 ambient = albedo * irr * bounceCol * (0.08 + 0.2 * max(-n.z, 0.0) + 0.06 * (1.0 - abs(n.z)));",
  "  ambient += albedo * vec3(0.006, 0.0055, 0.0045);",

  "  float ndv = max(dot(n, Vn), 0.0);",
  "  float eDist = length(ePos);",
  "  vec3 eDir = ePos / max(eDist, 0.001);",
  "  float cosA = -eDir.z;",
  "  float beam = smoothstep(0.78, 0.97, cosA);",
  "  float fall = 1.0 / (1.0 + eDist * eDist / 2000000.0);",
  "  vec3 flDiff = albedo / PI * ndv;",
  "  direct += flDiff * vec3(0.85, 0.92, 1.0) * (PI * flash * 1.2 * beam * fall * mix(1.0, 1.8, 1.0 - ndv));",
  "  direct += flDiff * vec3(1.0, 0.95, 0.85) * (PI * glow / (1.0 + dist * dist / 122500.0));",

  "  float ao = 1.0;",
  "  if (isLevel) {",
  "    vec2 f = wPos.xy - cc * cellSize;",
  "    if (abs(gn.z) > 0.5) {",
  "      float m = cellSize;",
  "      if (isOpen(cc + vec2(-1.0, 0.0)) < 0.5) m = min(m, f.x);",
  "      if (isOpen(cc + vec2( 1.0, 0.0)) < 0.5) m = min(m, cellSize - f.x);",
  "      if (isOpen(cc + vec2(0.0, -1.0)) < 0.5) m = min(m, f.y);",
  "      if (isOpen(cc + vec2(0.0,  1.0)) < 0.5) m = min(m, cellSize - f.y);",
  "      if (isOpen(cc + vec2(-1.0, -1.0)) < 0.5) m = min(m, length(f));",
  "      if (isOpen(cc + vec2( 1.0, -1.0)) < 0.5) m = min(m, length(vec2(cellSize - f.x, f.y)));",
  "      if (isOpen(cc + vec2(-1.0,  1.0)) < 0.5) m = min(m, length(vec2(f.x, cellSize - f.y)));",
  "      if (isOpen(cc + vec2( 1.0,  1.0)) < 0.5) m = min(m, length(vec2(cellSize) - f));",
  "      ao = mix(0.4, 1.0, smoothstep(0.0, 130.0, m));",
  "    } else {",
  "      ao = mix(0.45, 1.0, smoothstep(0.0, 100.0, wPos.z)) * mix(0.55, 1.0, smoothstep(0.0, 80.0, wallH - wPos.z));",
  "      float m = cellSize;",
  "      if (abs(gn.x) > 0.5) {",
  "        if (isOpen(cc + vec2(0.0, -1.0)) < 0.5) m = min(m, f.y);",
  "        if (isOpen(cc + vec2(0.0,  1.0)) < 0.5) m = min(m, cellSize - f.y);",
  "      } else {",
  "        if (isOpen(cc + vec2(-1.0, 0.0)) < 0.5) m = min(m, f.x);",
  "        if (isOpen(cc + vec2( 1.0, 0.0)) < 0.5) m = min(m, cellSize - f.x);",
  "      }",
  "      ao *= mix(0.55, 1.0, smoothstep(0.0, 120.0, m));",
  "    }",
  "  }",

  "  vec3 col = direct * mix(1.0, ao, 0.6) + ambient * ao + albedo * emissive * 1.6;",
  "  float fog = 1.0 - exp(-pow(dist / fogDist, 1.5));",
  "  col = mix(col, fogColor, fog);",

  "  if (volOn > 0.5) {",
  "    float scat = 0.0;",
  "    float rayLen = min(dist, 2600.0);",
  "    float jit = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));",
  "    for (int s = 0; s < 10; s++) {",
  "      float tt = (float(s) + jit) / 10.0 * rayLen;",
  "      vec3 sp = camPos - Vn * tt;",
  "      vec2 sc = floor(sp.xy / cellSize);",
  "      float lp = cellVal(sc);",
  "      if (lp <= 0.01) continue;",
  "      vec3 dlp = vec3((sc + 0.5) * cellSize, lampZ) - sp;",
  "      scat += lp / (1.0 + dot(dlp, dlp) / 48400.0);",
  "    }",
  "    col += lampCol * scat * rayLen / 10.0 * 0.0002;",
  "  }",

  "  col = aces(col * exposure);",
  "  gl_FragColor = vec4(pow(col, vec3(1.0 / 2.2)), 1.0);",
  "}"
};

String[] POST_VERT = {
  "#define PROCESSING_TEXTURE_SHADER",
  "uniform mat4 transformMatrix;",
  "uniform mat4 texMatrix;",
  "attribute vec4 position;",
  "attribute vec4 color;",
  "attribute vec2 texCoord;",
  "varying vec4 vertColor;",
  "varying vec4 vertTexCoord;",
  "void main() {",
  "  gl_Position = transformMatrix * position;",
  "  vertColor = color;",
  "  vertTexCoord = texMatrix * vec4(texCoord, 1.0, 1.0);",
  "}"
};

// Lens: the player's own eye/lens — fish-eye, grainy micro-blur and film grain. World + hands only.
String[] LENS_FRAG = {
  "#define PROCESSING_TEXTURE_SHADER",
  "#ifdef GL_ES",
  "precision mediump float;",
  "#endif",
  "uniform sampler2D texture;",
  "uniform vec2 texOffset;",
  "uniform float time;",
  "uniform float fisheye;",
  "uniform float aspect;",
  "uniform float grain;",
  "uniform float soft;",
  "varying vec4 vertColor;",
  "varying vec4 vertTexCoord;",
  "float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }",
  "void main() {",
  "  vec2 c0 = vertTexCoord.st - 0.5;",
  "  vec2 ca = vec2(c0.x * aspect, c0.y);",
  "  float r2 = dot(ca, ca);",
  "  float edge = 1.0 + fisheye * 0.25 * (aspect * aspect + 1.0);",
  "  vec2 uv = 0.5 + c0 * (1.0 + fisheye * r2) / edge;",
  "  float t = fract(time * 7.31) * 91.7;",
  "  float ang = rnd(gl_FragCoord.xy * 0.37 + t) * 6.28318;",
  "  float rad = soft * (0.6 + 1.6 * r2);",                                   // softer toward the edges
  "  vec2 j = vec2(cos(ang), sin(ang)) * texOffset * rad;",
  "  vec2 lo = texOffset, hi = vec2(1.0) - texOffset;",
  "  vec3 col = texture2D(texture, clamp(uv + j, lo, hi)).rgb * 0.55 + texture2D(texture, uv).rgb * 0.45;",
  "  vec3 b = texture2D(texture, clamp(uv + texOffset * vec2( 0.8,  0.8), lo, hi)).rgb",
  "         + texture2D(texture, clamp(uv + texOffset * vec2(-0.8,  0.8), lo, hi)).rgb",
  "         + texture2D(texture, clamp(uv + texOffset * vec2( 0.8, -0.8), lo, hi)).rgb",
  "         + texture2D(texture, clamp(uv + texOffset * vec2(-0.8, -0.8), lo, hi)).rgb;",
  "  col = mix(col, b * 0.25, 0.15);",
  "  float l = dot(col, vec3(0.299, 0.587, 0.114));",
  "  float g = rnd(gl_FragCoord.xy + t * 13.0) + rnd(gl_FragCoord.xy * 1.7 - t) - 1.0;",   // triangular grain
  "  col += g * grain * (0.35 + 1.3 * l * (1.0 - l));",                       // lives in the midtones
  "  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);",
  "}"
};

// Post: the camcorder (whole image, on-screen text included)
String[] POST_FRAG = {
  "#define PROCESSING_TEXTURE_SHADER",
  "#ifdef GL_ES",
  "precision mediump float;",
  "#endif",
  "uniform sampler2D texture;",
  "uniform vec2 texOffset;",
  "uniform float time;",
  "uniform float danger;",
  "uniform float hit;",
  "uniform float gain;",
  "uniform float vhs;",
  "uniform float fisheye;",
  "uniform float aspect;",
  "varying vec4 vertColor;",
  "varying vec4 vertTexCoord;",
  "float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }",
  "void main() {",
  "  vec2 c0 = vertTexCoord.st - 0.5;",
  "  vec2 ca = vec2(c0.x * aspect, c0.y);",
  "  float r2 = dot(ca, ca);",
  "  float edge = 1.0 + fisheye * 0.25 * (aspect * aspect + 1.0);",
  "  vec2 uv = 0.5 + c0 * (1.0 + fisheye * r2) / edge;",
  "  float row = floor(uv.y / texOffset.y / 3.0);",
  "  float jitter = (rnd(vec2(row, floor(time * 30.0))) - 0.5) * texOffset.x * (30.0 * danger * danger + 60.0 * hit);",
  "  float band = (1.0 - smoothstep(0.0, 0.025, abs(uv.y - fract(time * 0.11)))) * max(vhs, danger) * 0.6;",
  "  uv.x += jitter + band * texOffset.x * 4.0;",
  "  vec2 dir = uv - 0.5;",
  "  float ab = 0.0006 + 0.008 * danger + 0.03 * hit;",
  "  vec3 col;",
  "  col.r = texture2D(texture, uv + dir * ab).r;",
  "  col.g = texture2D(texture, uv).g;",
  "  col.b = texture2D(texture, uv - dir * ab).b;",
  "  vec3 nb = (texture2D(texture, uv + vec2(texOffset.x, 0.0)).rgb + texture2D(texture, uv - vec2(texOffset.x, 0.0)).rgb",
  "           + texture2D(texture, uv + vec2(0.0, texOffset.y)).rgb + texture2D(texture, uv - vec2(0.0, texOffset.y)).rgb) * 0.25;",
  "  col += (col - nb) * 0.15;",
  "  vec3 bloom = vec3(0.0);",
  "  for (int k = 0; k < 16; k++) {",
  "    float a = float(k) * 2.39996;",
  "    vec2 o = vec2(cos(a), sin(a)) * (3.0 + float(k) * 2.2) * texOffset * 2.0;",
  "    vec3 s = texture2D(texture, uv + o).rgb;",
  "    float l = max(max(s.r, s.g), s.b);",
  "    bloom += s * smoothstep(0.88, 1.0, l) / (1.0 + float(k) * 0.12);",
  "  }",
  "  bloom /= 9.0;",
  "  col += bloom * vec3(1.0, 0.92, 0.8) * 0.35 + bloom * vec3(0.2, 0.03, 0.0) * 0.25;",
  "  float luma = dot(col, vec3(0.299, 0.587, 0.114));",
  "  col = mix(vec3(luma), col, 0.92 - 0.4 * danger);",
  "  col *= vec3(1.02, 1.0, 0.92);",
  "  col = mix(col, vec3(luma * 1.2, luma * 0.35, luma * 0.3), 0.35 * hit + 0.15 * danger * danger);",
  "  col = clamp(col, 0.0, 1.0);",
  "  col = mix(col, col * col * (3.0 - 2.0 * col), 0.25);",
  "  col *= 1.0 - vhs * 0.05 * (0.5 + 0.5 * sin(uv.y / texOffset.y * 3.14159));",
  "  col += band * 0.04;",
  "  float n1 = rnd(uv * 731.0 + time) - 0.5;",
  "  float n2 = rnd(uv * 417.0 - time * 1.3) - 0.5;",
  "  col += vec3(n1, (n1 + n2) * 0.5, n2) * (0.012 + 0.03 * gain) * (1.0 - luma) + n1 * 0.06 * danger;",
  "  float v = 1.0 - smoothstep(0.35, 1.05, length(dir * vec2(1.2, 1.0)) + 0.15 * danger);",
  "  col *= mix(0.4, 1.0, v);",
  "  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);",
  "}"
};

// =====================================================================
void setup() {
  size(1360, 900, P3D);
  smooth(4);
  frameRate(120);
  surface.setTitle("BACKROOMS: Escape from the Nerdolas");
  win = (GLWindow) surface.getNative();

  carpet  = loadImage("carpet.jpg");
  wall    = loadImage("wall.jpg");
  roof    = loadImage("roof.jpg");
  menuImg = loadImage("menu.png");

  minim = new Minim(this);
  ambience = minim.loadFile("ambiente.mp3");
  ambience.loop();
  for (int k = 0; k < NAMES.length; k++) {
    String n = NAMES[k].toLowerCase();
    faces[k]  = loadImage(n + ".jpg");
    voices[k] = minim.loadFile(n + ".mp3");
  }
  setupSynth();

  if (new File(dataPath("flashlight.mp3")).exists()) {
    flashSnd = minim.loadSample("flashlight.mp3", 512);
    if (flashSnd.hasControl(Controller.GAIN)) flashSnd.setGain(-4);
  }

  loadSettings();
  applyVolumes();

  fontBig      = createFont("SansSerif.bold", 96, true);
  fontUI       = createFont("SansSerif.bold", 32, true);
  fontMono     = createFont("Monospaced.bold", 28, true);
  fontGraffiti = createFont("SansSerif.bold", 110, true);
  fontHud      = createFont("Impact", 48, true);
  fontMail     = createFont("SansSerif", 22, true);

  textureMode(NORMAL);
  textureWrap(REPEAT);

  world = new PShader(this, WORLD_VERT, WORLD_FRAG);
  post  = new PShader(this, POST_VERT, POST_FRAG);
  lens  = new PShader(this, POST_VERT, LENS_FRAG);

  panelTex  = makePanel();
  outletTex = makeOutlet();
  ventTex   = makeVent();
  staticImg = createImage(240, 150, RGB);
  for (int k = 0; k < ITEM_NAMES.length; k++) itemTex[k] = makeItem(k);
  canModel = loadCan("monster.obj");
  pizzaModel = loadModel("pizza.obj", "pizza.jpg");
  clanks = makeClanks();
  for (int k = 0; k < WALL_MSGS.length; k++) graffiti[k] = makeGraffiti(WALL_MSGS[k], 100 + k);
  certTex = makeCert();
  cabralMark = makeCabralMark();
  exitTex = makeExit();
  arrowTex = makeArrow();
  pucprBg = loadPucpr();
  initModels();

  loadSaves();
  pwSel = unlockedDays() - 1;
  lastMs = millis();
}

void flashClick() {
  if (flashSnd != null) flashSnd.trigger();
}

void draw() {
  int now = millis();
  float dt = min((now - lastMs) / 1000.0, 0.05);
  lastMs = now;
  frameDt = dt;

  if (state == PLAYING && !paused && !focused) pauseGame();   // alt-tab pauses
  if (state == PLAYING && paused) {
    drawPause();
  } else if (state == PLAYING) {
    update(dt);
    if (state == PLAYING) render();
    else if (state == WIN) drawWin();
    else drawDeath();
  } else if (state == DEAD) {
    drawDeath();
  } else if (state == WIN) {
    drawWin();
  } else if (state == EMAIL) {
    drawEmail();
  } else {
    drawMenu();
  }
  tickUiAudio(dt);
}

// =====================================================================
// AUDIO
void setupSynth() {
  out = minim.getLineOut();
  hum  = new Oscil(120, 0, Waves.SINE);
  hum2 = new Oscil(240, 0, Waves.TRIANGLE);
  heart = new Oscil(52, 0, Waves.SINE);
  hum.patch(out);
  hum2.patch(out);
  heart.patch(out);

  stepAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.BROWN).patch(new MoogFilter(280, 0.25)).patch(stepAmp).patch(out);
  breathAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.PINK).patch(new MoogFilter(1400, 0.15)).patch(breathAmp).patch(out);
  staticAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.WHITE).patch(staticAmp).patch(out);

  MoogFilter stingLP = new MoogFilter(2200, 0.3);
  for (int k = 0; k < 3; k++) {
    sting[k] = new Oscil(STING_F[k], 0, Waves.SAW);
    sting[k].patch(stingLP);
  }
  stingLP.patch(out);
  boom = new Oscil(48, 0, Waves.SINE);
  boom.patch(out);
  screech = new Oscil(1800, 0, Waves.TRIANGLE);
  screech.patch(out);

  droneLP = new MoogFilter(300, 0.5);
  drone1 = new Oscil(55, 0, Waves.SAW);
  drone2 = new Oscil(55.7, 0, Waves.SAW);
  drone1.patch(droneLP);
  drone2.patch(droneLP);
  droneLP.patch(out);
  kick = new Oscil(60, 0, Waves.SINE);
  kick.patch(out);
  tickAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.WHITE).patch(new MoogFilter(7000, 0.1)).patch(tickAmp).patch(out);

  achOsc = new Oscil(784, 0, Waves.TRIANGLE);
  achOsc.patch(out);
}

void updateSynth(float dt, float dg) {
  stepEnv *= exp(-dt * 16);
  stepAmp.setValue(stepEnv);

  hbPhase += dt * (55 + 115 * dg) / 60.0;
  float ph = hbPhase - floor(hbPhase);
  float beat = exp(-ph * 28) + (ph > 0.2 ? 0.7 * exp(-(ph - 0.2) * 28) : 0);
  heart.setAmplitude(beat * dg * 0.7);

  hum.setAmplitude(0.035 * humLevel);
  hum2.setAmplitude(0.008 * humLevel);

  float need = exhausted ? 1 : sq(1 - stamina / staminaMax()) * 0.6;
  breathPhase += dt * (exhausted ? 1.6 : 1.1);
  breathAmp.setValue(need * 0.1 * sq(max(0, sin(breathPhase * TWO_PI))) * (crouching ? 0.5 : 1));

  staticBurst *= exp(-dt * 6);
  staticAmp.setValue(0.04 * pow(dg, 3) + staticBurst);

  if (stingT >= 0) {
    stingT += dt;
    float env = stingT < 0.05 ? stingT / 0.05 : exp(-(stingT - 0.05) * 1.6);
    for (int k = 0; k < 3; k++) {
      sting[k].setFrequency(STING_F[k] * (1 - 0.3 * min(1, stingT / 1.8)));
      sting[k].setAmplitude(0.09 * env);
    }
    boom.setFrequency(48 - 18 * min(1, stingT));
    boom.setAmplitude(0.8 * exp(-stingT * 3));
    screech.setFrequency(1800 + 800 * min(1, stingT) + 300 * sin(stingT * 40));
    screech.setAmplitude(0.05 * exp(-stingT * 2.5));
    if (stingT > 3) {
      stingT = -1;
      for (Oscil o : sting) o.setAmplitude(0);
      boom.setAmplitude(0);
      screech.setAmplitude(0);
    }
  }

  float target = anyChase ? 1 : 0;
  chaseLvl += (target - chaseLvl) * min(1, dt * (target > chaseLvl ? 3 : 0.5));
  float bpm = 130 + 50 * dg;
  if (chaseLvl > 0.02) {
    chaseBeat += dt * bpm / 60.0 * 4;
    int st = floor(chaseBeat);
    if (st != lastBeatStep) {
      lastBeatStep = st;
      int pos = st % 16;
      if (pos % 4 == 0) kickEnv = 1;
      else if (pos == 6 || pos == 14) kickEnv = 0.7;
      tickEnv = (pos % 2 == 1) ? 0.18 : 0.08;
    }
  }
  kickEnv *= exp(-dt * 14);
  tickEnv *= exp(-dt * 35);
  kick.setFrequency(42 + 90 * kickEnv);
  kick.setAmplitude(kickEnv * 0.75 * chaseLvl);
  tickAmp.setValue(tickEnv * chaseLvl);
  drone1.setAmplitude(0.06 * chaseLvl);
  drone2.setAmplitude(0.06 * chaseLvl);
  droneLP.frequency.setLastValue(180 + 900 * chaseLvl * (0.5 + 0.5 * sin(millis() * 0.001 * bpm / 60.0 * PI)));
}

void tickUiAudio(float dt) {
  if (achT >= 0) {
    achT += dt;
    float[] notes = {784, 988, 1318.5};
    achOsc.setFrequency(notes[min(2, floor(achT / 0.09))]);
    achOsc.setAmplitude(0.07 * (achT < 0.35 ? 1 : exp(-(achT - 0.35) * 6)));
    if (achT > 1.3) {
      achT = -1;
      achOsc.setAmplitude(0);
    }
  }
  if (state == MENU) {
    menuStatic *= exp(-dt * 8);
    staticAmp.setValue(0.012 + menuStatic);
  }
}

void triggerSting(Enemy e) {
  int now = millis();
  e.screamUntil = now + 1200;
  if (now - lastStingMs < 5000) return;
  lastStingMs = now;
  stingT = 0;
  spotFlash = 1;
}

void silenceSynth() {
  hum.setAmplitude(0);
  hum2.setAmplitude(0);
  heart.setAmplitude(0);
  stepAmp.setValue(0);
  breathAmp.setValue(0);
  staticAmp.setValue(0);
  staticBurst = 0;
  for (Oscil o : sting) o.setAmplitude(0);
  boom.setAmplitude(0);
  screech.setAmplitude(0);
  stingT = -1;
  drone1.setAmplitude(0);
  drone2.setAmplitude(0);
  kick.setAmplitude(0);
  tickAmp.setValue(0);
  chaseLvl = kickEnv = tickEnv = 0;
}

void pauseVoices() {
  for (AudioPlayer v : voices) v.pause();
}

// =====================================================================
// SAVES, PROGRESS & ACHIEVEMENTS
void loadSaves() {
  if (new File(sketchPath("best.txt")).exists()) best = float(loadStrings("best.txt")[0]);
  if (new File(sketchPath("best_fuga.txt")).exists()) bestFuga = float(loadStrings("best_fuga.txt")[0]);
  if (new File(sketchPath("achievements.txt")).exists()) {
    String[] s = loadStrings("achievements.txt");
    for (int k = 0; k < min(s.length, achUnlocked.length); k++) achUnlocked[k] = s[k].trim().equals("1");
  }
  if (new File(sketchPath("progress.txt")).exists()) {
    for (String line : loadStrings("progress.txt")) {
      String[] kv = split(line.trim(), '=');
      if (kv.length < 2) continue;
      String k = kv[0], v = kv[1];
      if (k.startsWith("day")) {
        int d = int(k.substring(3));
        String[] p = split(v, ',');
        if (d >= 0 && d < 8 && p.length >= 2) {
          dayBeaten[d] = p[0].equals("1");
          dayCerts[d] = int(p[1]);
        }
      } else if (k.equals("final")) finalBeaten = v.equals("1");
      else if (k.equals("msgs")) readBits(v, msgSeen);
      else if (k.equals("items")) readBits(v, itemSeen);
      else if (k.equals("pizza")) readBits(v, pizzaGot);
      else if (k.equals("stats")) {
        String[] p = split(v, ',');
        if (p.length >= 9) {
          totalRuns = int(p[0]);
          totalDeaths = int(p[1]);
          totalTime = float(p[2]);
          totalItems = int(p[3]);
          totalConsumed = int(p[4]);
          totalStuns = int(p[5]);
          totalEscapes = int(p[6]);
          totalCerts = int(p[7]);
          totalWins = int(p[8]);
        }
      }
    }
  }
  endlessUnlocked = finalBeaten;
  recupUnlocked = finalBeaten && hoursValidated() >= DAYS * CERTS_PER_DAY * HOURS_PER_CERT;
}

void readBits(String s, boolean[] arr) {
  for (int k = 0; k < min(s.length(), arr.length); k++) arr[k] = s.charAt(k) == '1';
}

String bits(boolean[] arr) {
  String s = "";
  for (boolean b : arr) s += b ? "1" : "0";
  return s;
}

void saveProgress() {
  ArrayList<String> L = new ArrayList<String>();
  for (int d = 0; d < 8; d++) L.add("day" + d + "=" + (dayBeaten[d] ? 1 : 0) + "," + dayCerts[d]);
  L.add("final=" + (finalBeaten ? 1 : 0));
  L.add("endless=" + (endlessUnlocked ? 1 : 0));
  L.add("msgs=" + bits(msgSeen));
  L.add("items=" + bits(itemSeen));
  L.add("pizza=" + bits(pizzaGot));
  L.add("stats=" + totalRuns + "," + totalDeaths + "," + totalTime + "," + totalItems + "," + totalConsumed + ","
    + totalStuns + "," + totalEscapes + "," + totalCerts + "," + totalWins);
  saveStrings("progress.txt", L.toArray(new String[0]));
}

int hoursValidated() {
  int h = 0;
  for (int d = 0; d < DAYS; d++) h += min(dayCerts[d], CERTS_PER_DAY) * HOURS_PER_CERT;
  return h;
}

int unlockedDays() {
  int n = 1;
  while (n <= FINAL_DAY && dayBeaten[n - 1]) n++;
  return n;
}

boolean dayKnown(int d) { return d < unlockedDays(); }

void saveAch() {
  String[] s = new String[achUnlocked.length];
  for (int k = 0; k < s.length; k++) s[k] = achUnlocked[k] ? "1" : "0";
  saveStrings("achievements.txt", s);
}

void unlock(int id) {
  if (achUnlocked[id] || ACH_MODE[id] != gameMode) return;
  achUnlocked[id] = true;
  runAch.add(id);
  if (toastQueue.isEmpty()) toastStart = millis();
  toastQueue.add(id);
  achT = 0;
  saveAch();
}

boolean achVisible(int k) { return ACH_MODE[k] == FUGA || endlessUnlocked; }

int achCountVisible() {
  int c = 0;
  for (int k = 0; k < achUnlocked.length; k++) if (achVisible(k) && achUnlocked[k]) c++;
  return c;
}

int achTotalVisible() {
  int c = 0;
  for (int k = 0; k < ACH_MODE.length; k++) if (achVisible(k)) c++;
  return c;
}

void checkAchievements(float d, Enemy ne) {
  int now = millis();
  if (gameMode != ENDLESS || ne == null) return;
  if (survived >= 60) unlock(0);
  if (survived >= 180) unlock(1);
  if (survived >= 420) unlock(2);
  if (survived >= 300 && itemsUsed == 0 && useType < 0) unlock(14);
  if (crouching && survived > graceTime && ne.ai != CHASE && now >= ne.stunUntil && now >= ne.confusedUntil && d < CELL * 1.5) unlock(8);
  if (sprintTime >= 90) unlock(10);
  if (darkStreak >= 120) unlock(11);
  boolean all = true;
  for (boolean b : readMsg) all &= b;
  if (all) unlock(13);
  if (survived >= 180 && usedCount[COXINHA] >= 3 && usedCount[SALADA] + usedCount[LAGRIMAS] + usedCount[CESTA] == 0) unlock(19);
  if (survived >= 300 && tasersFired == 0 && inv[TASER] > 0) unlock(20);
  if (openCells > 0 && visitedCount >= openCells * 0.8) unlock(24);
  if (survived >= 120 && sprintTime == 0) unlock(25);
}

// lifetime stats, counted once per run
void endRun(boolean died) {
  if (runCounted) return;
  runCounted = true;
  totalRuns++;
  if (died) totalDeaths++;
  totalTime += survived;
  totalItems += itemsCollected;
  totalConsumed += itemsUsed;
  totalStuns += stuns;
  totalEscapes += chasesEscaped;
  if (gameMode == FUGA) totalCerts += certsTaken;
  saveProgress();
}

String fmtTime(float s) {
  return int(s / 60) + ":" + nf(s % 60, 2, 1);
}

float mapScale() { return sq(GRID / 25.0); }

// =====================================================================
// GAME START
void startRun(int mode, int entry) {
  gameMode = mode;
  runEntry = entry;
  runDay = mode == FUGA ? entry : -1;
  boolean allSix = mode == FUGA ? runDay >= FINAL_DAY : entry >= 6;
  boolean blackout = mode == FUGA && runDay == RECUP_DAY;
  int[] roster = allSix ? new int[]{0, 1, 2, 3, 4, 5} : new int[]{mode == FUGA ? DAY_ORDER[runDay] : entry};
  GRID = mode == ENDLESS ? GRID_ENDLESS : (allSix ? GRID_FINAL : GRID_DAY);
  graceTime = GRACE_TIME + (roster.length > 1 ? 2 : 0);

  generateMaze();
  level = buildLevel();

  lampType = new int[GRID][GRID];
  lampP = new float[GRID][GRID];
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    float r = random(1);
    lampType[i][j] = blackout ? 2 : (r < 0.08 ? 2 : (r < 0.18 ? 1 : 0));
  }
  // dead ends: most have a dead lamp, so there are dark corners to hide in
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    if (isWall(i, j)) continue;
    int open = 0;
    for (int[] d : DIRS) if (!isWall(i + d[0], j + d[1])) open++;
    if (open == 1 && random(1) < DEADEND_DARK) lampType[i][j] = 2;
  }

  int[] c = randomOpenCell();
  if (!blackout) lampType[c[0]][c[1]] = 0;
  player.set((c[0] + 0.5) * CELL, (c[1] + 0.5) * CELL);
  yaw = random(TWO_PI);
  pitch = 0;
  pvx = pvy = 0;

  flowI = -1;
  updateFlow();
  spawnEnemies(roster);

  spotFlash = 0;
  lastStingMs = -99999;
  eyeOpen = eyeLX = eyeLY = 0;
  blinkUntil = 0;
  nextBlink = millis() + 2000;
  anyChase = false;

  survived = 0;
  drops.clear();
  dropBag.clear();
  parts.clear();
  int nDrops = round(DROPS * mapScale());
  for (int k = 0; k < nDrops; k++) spawnDrop();
  placeSecrets();
  placeDecals();
  placeProps();
  markSecrets();
  certs.clear();
  certsTaken = 0;
  exitOpen = false;
  arrows.clear();
  nearCert = -1;
  if (mode == FUGA) {
    certsPlaced = runDay == RECUP_DAY ? 1 : (runDay == FINAL_DAY ? CERTS_FINAL : CERTS_PER_DAY);
    certsRequired = runDay == RECUP_DAY ? 1 : (runDay == FINAL_DAY ? CERTS_FINAL : CERTS_TO_EXIT);
    placeCerts();
    chooseExit();
    placeArrows();
  }

  java.util.Arrays.fill(inv, 0);
  inv[LATA] = START_CANS;
  itemSeen[LATA] = true;
  useType = -1;
  energyUntil = swiftUntil = ghostUntil = fedUntil = pilhadoUntil = 0;
  fireUntil = 0;
  lastThrow = 0;
  cans.clear();
  itemsUsed = stuns = 0;

  itemsCollected = chasesEscaped = 0;
  sprintTime = darkTime = 0;
  java.util.Arrays.fill(usedType, false);
  java.util.Arrays.fill(readMsg, false);
  everSpotted = false;
  runCounted = false;
  pickupTimes.clear();
  java.util.Arrays.fill(collectedType, 0);
  java.util.Arrays.fill(usedCount, 0);
  tasersFired = chasesStarted = 0;
  darkStreak = dropTimer = 0;
  visited = new boolean[GRID][GRID];
  visitedCount = 0;
  openCells = 0;
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) if (!solid[i][j]) openCells++;
  runAch.clear();

  stamina = STAMINA_MAX * pizzaMul();
  exhausted = false;
  msgUntil = 0;
  eyeH = EYE_H;
  fov = radians(72);
  exposureAdapt = 1;
  roll = bobPhase = stepEnv = hbPhase = staticBurst = chewTimer = 0;
  peekSide = peekDir = 0;
  paused = false;
  peekAmt = 0;
  peekL = peekR = null;
  lastStep = 0;
  flicker = 1;
  flickerUntil = 0;
  crouchToggle = false;
  releaseKeys();
  silenceSynth();

  pauseVoices();
  for (Enemy e : enemies) {
    voices[e.ch].rewind();
    voices[e.ch].loop();
  }

  startMs = millis();
  state = PLAYING;
  updateLampGrid();
  lockMouse(true);
}

void spawnEnemies(int[] roster) {
  enemies.clear();
  int maxD = 0;
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) maxD = max(maxD, flow[i][j]);
  for (int ch : roster) {
    Enemy e = new Enemy();
    e.ch = ch;
    boolean placed = false;
    for (int tries = 0; tries < 600 && !placed; tries++) {
      int[] c = randomOpenCell();
      boolean relaxed = tries > 400;
      if (flow[c[0]][c[1]] < maxD * (relaxed ? 0.35 : 0.55)) continue;
      float x = (c[0] + 0.5) * CELL, y = (c[1] + 0.5) * CELL;
      boolean ok = true;
      for (Enemy o : enemies) if (dist(o.pos.x, o.pos.y, x, y) < CELL * (relaxed ? 3 : 7)) ok = false;
      if (!ok) continue;
      e.pos.set(x, y);
      placed = true;
    }
    if (!placed) {
      int[] c = randomOpenCell();
      e.pos.set((c[0] + 0.5) * CELL, (c[1] + 0.5) * CELL);
    }
    e.nextTeleport = millis() + (int) (graceTime * 1000) + (int) random(14000, 24000);
    enemies.add(e);
  }
}

void goMenu() {
  if (state == PLAYING) endRun(false);
  state = MENU;
  menuPage = 0;
  lineShift = 0;
  pwSel = constrain(pwSel, 0, unlockedDays() - 1);
  pageSwitchMs = millis();
  lockMouse(false);
  silenceSynth();
  pauseVoices();
}

void die(Enemy killer) {
  state = DEAD;
  deathMs = millis();
  killerCh = killer.ch;
  lockMouse(false);
  silenceSynth();
  pauseVoices();
  voices[killerCh].play();
  setVoice(voices[killerCh], 6 + volDb(V_VOICE), 0);
  newRecord = false;
  if (gameMode == ENDLESS && survived > best) {
    newRecord = true;
    best = survived;
    saveStrings("best.txt", new String[]{str(best)});
  }
  endRun(true);
}

void escapeWin() {
  state = WIN;
  winMs = millis();
  winFaceCh = enemies.get((int) random(enemies.size())).ch;
  lockMouse(false);
  silenceSynth();
  pauseVoices();
  unlock(15);
  if (survived < 180) unlock(16);
  if (!everSpotted) unlock(17);
  if (itemsUsed == 0) unlock(26);
  if (chasesStarted >= 5) unlock(27);
  newRecordFuga = bestFuga <= 0 || survived < bestFuga;
  if (newRecordFuga) {
    bestFuga = survived;
    saveStrings("best_fuga.txt", new String[]{str(bestFuga)});
  }

  // progression
  winHoursBefore = hoursValidated();
  boolean firstFinal = runDay == FINAL_DAY && !finalBeaten;
  dayBeaten[runDay] = true;
  if (runDay < DAYS) dayCerts[runDay] = max(dayCerts[runDay], min(certsTaken, CERTS_PER_DAY));
  if (runDay == FINAL_DAY) finalBeaten = true;
  if (runDay == RECUP_DAY) unlock(30);
  int h = hoursValidated();
  int full = DAYS * CERTS_PER_DAY * HOURS_PER_CERT;
  emailSuccess = h >= full;
  emailFirst = firstFinal;
  emailPending = firstFinal || (finalBeaten && h >= full && winHoursBefore < full);
  endlessUnlocked = finalBeaten;
  recupUnlocked = finalBeaten && emailSuccess;
  totalWins++;
  endRun(false);
  pwSel = unlockedDays() - 1;
  saveProgress();
}

void openEmail() {
  state = EMAIL;
  emailMs = millis();
  if (finalBeaten) unlock(28);
  if (emailSuccess) unlock(29);
  emailPending = false;
  saveProgress();
}

void showMsg(String s) {
  msg = s;
  msgUntil = millis() + 2200;
}

// =====================================================================
// MAZE GENERATION
void generateMaze() {
  solid = new boolean[GRID][GRID];
  for (boolean[] row : solid) java.util.Arrays.fill(row, true);

  ArrayList<int[]> stack = new ArrayList<int[]>();
  solid[1][1] = false;
  stack.add(new int[]{1, 1});
  while (stack.size() > 0) {
    int[] cur = stack.get(stack.size() - 1);
    ArrayList<int[]> options = new ArrayList<int[]>();
    for (int[] d : DIRS) {
      int ni = cur[0] + d[0] * 2, nj = cur[1] + d[1] * 2;
      if (ni > 0 && nj > 0 && ni < GRID - 1 && nj < GRID - 1 && solid[ni][nj]) options.add(new int[]{ni, nj});
    }
    if (options.isEmpty()) {
      stack.remove(stack.size() - 1);
      continue;
    }
    int[] nxt = options.get((int) random(options.size()));
    solid[(cur[0] + nxt[0]) / 2][(cur[1] + nxt[1]) / 2] = false;
    solid[nxt[0]][nxt[1]] = false;
    stack.add(nxt);
  }

  for (int i = 1; i < GRID - 1; i++) for (int j = 1; j < GRID - 1; j++) {
    if (!solid[i][j] || random(1) > 0.12) continue;
    boolean h = !solid[i - 1][j] && !solid[i + 1][j];
    boolean v = !solid[i][j - 1] && !solid[i][j + 1];
    if (h ^ v) solid[i][j] = false;
  }

  int rooms = round(5 * mapScale());
  for (int r = 0; r < rooms; r++) {
    int w = (int) random(3, 6), h = (int) random(3, 6);
    int i0 = (int) random(1, GRID - 1 - w), j0 = (int) random(1, GRID - 1 - h);
    for (int i = i0; i < i0 + w; i++) for (int j = j0; j < j0 + h; j++) solid[i][j] = false;
  }
}

int[] randomOpenCell() {
  while (true) {
    int i = (int) random(GRID), j = (int) random(GRID);
    if (!solid[i][j]) return new int[]{i, j};
  }
}

int cellOf(float v) { return floor(v / CELL); }

boolean isWall(int i, int j) {
  return i < 0 || j < 0 || i >= GRID || j >= GRID || solid[i][j];
}

// =====================================================================
// LEVEL MESH
PShape buildLevel() {
  PShape floorS = startMesh(carpet), ceilS = startMesh(roof), wallS = startMesh(wall);
  float vRep = WALL_H / CELL;
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    if (solid[i][j]) continue;
    float x0 = i * CELL, y0 = j * CELL, x1 = x0 + CELL, y1 = y0 + CELL;
    addQuad(floorS, new PVector(x0, y0, 0), new PVector(CELL, 0, 0), new PVector(0, CELL, 0), 1, 1);
    addQuad(ceilS, new PVector(x0, y0, WALL_H), new PVector(CELL, 0, 0), new PVector(0, CELL, 0), 1, 1);
    PVector down = new PVector(0, 0, -WALL_H);
    if (isWall(i - 1, j)) addQuad(wallS, new PVector(x0, y0, WALL_H), new PVector(0, CELL, 0), down, 1, vRep);
    if (isWall(i + 1, j)) addQuad(wallS, new PVector(x1, y0, WALL_H), new PVector(0, CELL, 0), down, 1, vRep);
    if (isWall(i, j - 1)) addQuad(wallS, new PVector(x0, y0, WALL_H), new PVector(CELL, 0, 0), down, 1, vRep);
    if (isWall(i, j + 1)) addQuad(wallS, new PVector(x0, y1, WALL_H), new PVector(CELL, 0, 0), down, 1, vRep);
  }
  floorS.endShape();
  ceilS.endShape();
  wallS.endShape();
  PShape grp = createShape(GROUP);
  grp.addChild(floorS);
  grp.addChild(ceilS);
  grp.addChild(wallS);
  return grp;
}

PShape startMesh(PImage tex) {
  PShape s = createShape();
  s.beginShape(QUADS);
  s.noStroke();
  s.fill(255);
  s.texture(tex);
  return s;
}

void addQuad(PShape s, PVector o, PVector a, PVector b, float uRep, float vRep) {
  corner(s, o, a, b, 0, 0, uRep, vRep);
  corner(s, o, a, b, 1, 0, uRep, vRep);
  corner(s, o, a, b, 1, 1, uRep, vRep);
  corner(s, o, a, b, 0, 1, uRep, vRep);
}

void corner(PShape s, PVector o, PVector a, PVector b, float u, float v, float uRep, float vRep) {
  s.vertex(o.x + a.x * u + b.x * v, o.y + a.y * u + b.y * v, o.z + a.z * u + b.z * v, u * uRep, v * vRep);
}

// =====================================================================
// SURFACE DETAIL TEXTURES
PImage makePanel() {
  PGraphics g = createGraphics(128, 64);
  g.beginDraw();
  g.background(80);
  g.noStroke();
  g.fill(130);
  g.rect(2, 2, 124, 60);
  g.fill(255);
  g.rect(7, 7, 114, 50);
  g.stroke(228);
  g.strokeWeight(1);
  for (int x = 10; x < 121; x += 4) g.line(x, 7, x, 57);
  for (int y = 10; y < 57; y += 4) g.line(7, y, 121, y);
  g.noStroke();
  g.fill(215);
  g.rect(7, 30, 114, 3);
  g.endDraw();
  return g.get();
}

PImage makeOutlet() {
  PGraphics g = createGraphics(64, 96);
  g.beginDraw();
  g.clear();
  g.noStroke();
  g.fill(200, 195, 180);
  g.rect(3, 3, 58, 90, 7);
  g.fill(238, 234, 222);
  g.rect(5, 5, 54, 86, 6);
  for (int k = 0; k < 2; k++) {
    float cy = 28 + k * 40;
    g.fill(210, 205, 192);
    g.ellipse(32, cy, 34, 34);
    g.fill(228, 224, 212);
    g.ellipse(32, cy, 28, 28);
    g.fill(35);
    g.ellipse(24, cy - 2, 6, 6);
    g.ellipse(40, cy - 2, 6, 6);
    g.ellipse(32, cy + 8, 6, 6);
  }
  g.fill(170);
  g.ellipse(32, 48, 4, 4);
  g.endDraw();
  return g.get();
}

PImage makeVent() {
  PGraphics g = createGraphics(128, 64);
  g.beginDraw();
  g.clear();
  g.noStroke();
  g.fill(120, 118, 110);
  g.rect(0, 0, 128, 64, 3);
  g.fill(175, 172, 162);
  g.rect(3, 3, 122, 58, 2);
  for (int y = 9; y < 58; y += 7) {
    g.fill(30, 28, 24);
    g.rect(9, y, 110, 4);
    g.fill(205, 202, 192);
    g.rect(9, y + 4, 110, 1);
  }
  g.fill(90);
  g.ellipse(6, 6, 4, 4);
  g.ellipse(122, 6, 4, 4);
  g.ellipse(6, 58, 4, 4);
  g.ellipse(122, 58, 4, 4);
  g.endDraw();
  return g.get();
}

// blurry campus for the final e-mail: data/pucpr.png if present, otherwise a generated one
PImage loadPucpr() {
  PImage img = null;
  if (new File(dataPath("pucpr.png")).exists()) img = loadImage("pucpr.png");
  if (img == null) img = makeCampus();
  img.resize(480, 0);
  img.filter(BLUR, 3);
  return img;
}

PImage makeCampus() {
  java.util.Random rng = new java.util.Random(5);
  PGraphics g = createGraphics(480, 300);
  g.beginDraw();
  g.noStroke();
  for (int y = 0; y < 300; y++) {
    g.fill(lerpColor(color(140, 180, 225), color(225, 230, 235), y / 170.0));
    g.rect(0, y, 480, 1);
  }
  for (int k = 0; k < 7; k++) {
    float bx = k * 72 - 20 + rng.nextFloat() * 20, bw = 80 + rng.nextFloat() * 50, bh = 90 + rng.nextFloat() * 90;
    g.fill(k % 2 == 0 ? color(170, 85, 70) : color(205, 200, 190));
    g.rect(bx, 220 - bh, bw, bh);
    g.fill(70, 90, 110);
    for (float wy = 230 - bh; wy < 205; wy += 16) for (float wx = bx + 8; wx < bx + bw - 10; wx += 14) g.rect(wx, wy, 8, 9);
  }
  g.fill(165, 28, 40);
  g.rect(190, 120, 100, 18);
  g.fill(90, 140, 70);
  g.rect(0, 215, 480, 85);
  for (int k = 0; k < 9; k++) {
    g.fill(55 + rng.nextFloat() * 30, 100 + rng.nextFloat() * 40, 50);
    g.ellipse(rng.nextFloat() * 480, 205 + rng.nextFloat() * 20, 50 + rng.nextFloat() * 40, 60 + rng.nextFloat() * 30);
  }
  g.endDraw();
  return g.get();
}

// =====================================================================
// WALL WRITINGS AND PROPS
PImage makeGraffiti(String text, int seed) {
  java.util.Random rng = new java.util.Random(seed);
  PGraphics g = createGraphics(1024, 512);
  g.beginDraw();
  g.clear();
  g.textFont(fontGraffiti);
  g.textAlign(CENTER, CENTER);
  String[] lines = split(text, '\n');
  float size = 110;
  g.textSize(size);
  float maxW = 0;
  for (String l : lines) maxW = max(maxW, g.textWidth(l));
  if (maxW > 940) size *= 940 / maxW;
  g.textSize(size);
  g.textLeading(size * 1.15);
  maxW = 0;
  for (String l : lines) maxW = max(maxW, g.textWidth(l));
  g.translate(512, 256);
  g.rotate(-0.035);
  g.noStroke();
  for (int p = 0; p < 7; p++) {
    g.fill(130 + rng.nextFloat() * 40, 10, 8, p == 6 ? 255 : 110);
    g.text(text, (rng.nextFloat() - 0.5) * 7, (rng.nextFloat() - 0.5) * 7);
  }
  float lead = size * 1.15;
  for (int k = 0; k < 26; k++) {
    int li = (int) (rng.nextFloat() * lines.length);
    float y = (li - (lines.length - 1) / 2.0) * lead + size * 0.36;
    float x = (rng.nextFloat() - 0.5) * maxW * 0.95;
    float sw = 2 + rng.nextFloat() * 4;
    float len = 10 + rng.nextFloat() * rng.nextFloat() * 90;
    g.stroke(140, 12, 10, 230);
    g.strokeWeight(sw);
    g.line(x, y, x, y + len);
    g.noStroke();
    g.fill(140, 12, 10, 230);
    g.ellipse(x, y + len, sw + 2, sw + 3);
  }
  g.endDraw();
  return g.get();
}

void placeDecals() {
  decals.clear();
  ArrayList<String> used = new ArrayList<String>();
  int placed = 0;
  int count = round(DECALS * mapScale());
  for (int tries = 0; tries < 6000 && placed < count; tries++) {
    int[] c = randomOpenCell();
    if (placed == 0 && tries < 1500 && (flow[c[0]][c[1]] < 1 || flow[c[0]][c[1]] > 3)) continue;
    if (placed == 1 && tries < 3000 && (flow[c[0]][c[1]] < 2 || flow[c[0]][c[1]] > 6)) continue;
    int[] d = DIRS[(int) random(4)];
    if (!wallFace(c[0] + d[0], c[1] + d[1])) continue;
    String face = c[0] + "," + c[1] + "," + d[0] + "," + d[1];
    if (used.contains(face)) continue;
    used.add(face);
    Decal dc = new Decal();
    dc.nx = -d[0];
    dc.ny = -d[1];
    dc.cx = (c[0] + 0.5) * CELL + d[0] * (CELL * 0.5 - 2);
    dc.cy = (c[1] + 0.5) * CELL + d[1] * (CELL * 0.5 - 2);
    dc.z = random(175, 245);
    dc.w = CELL * 0.9;
    dc.h = dc.w * 0.5;
    dc.msg = placed == 1 ? CABRAL_MSG : (placed == 0 ? 0 : placed - 1) % (WALL_MSGS.length - 1);
    dc.tex = graffiti[dc.msg];
    decals.add(dc);
    placed++;
  }
}

void placeProps() {
  ArrayList<String> used = new ArrayList<String>();
  int nOut = round(OUTLETS * mapScale()), nVent = round(VENTS * mapScale());
  for (int k = 0; k < nOut + nVent; k++) {
    boolean vent = k >= nOut;
    for (int tries = 0; tries < 200; tries++) {
      int[] c = randomOpenCell();
      int[] d = DIRS[(int) random(4)];
      if (!wallFace(c[0] + d[0], c[1] + d[1])) continue;
      String face = (vent ? "v" : "o") + c[0] + "," + c[1] + "," + d[0] + "," + d[1];
      if (used.contains(face)) continue;
      used.add(face);
      Decal dc = new Decal();
      dc.nx = -d[0];
      dc.ny = -d[1];
      float slide = random(-CELL * 0.3, CELL * 0.3);
      dc.cx = (c[0] + 0.5) * CELL + d[0] * (CELL * 0.5 - 1.5) + dc.ny * slide;
      dc.cy = (c[1] + 0.5) * CELL + d[1] * (CELL * 0.5 - 1.5) - dc.nx * slide;
      dc.w = vent ? 96 : 28;
      dc.h = vent ? 48 : 42;
      dc.z = vent ? WALL_H - 50 : 46;
      dc.msg = -1;
      dc.tex = vent ? ventTex : outletTex;
      decals.add(dc);
      break;
    }
  }
}

void drawDecals() {
  world.set("emissive", 0.0);
  textureWrap(CLAMP);
  noStroke();
  noTint();
  for (Decal dc : decals) {
    if (dist(player.x, player.y, dc.cx, dc.cy) > CELL * 8) continue;
    float rx = dc.ny, ry = -dc.nx;
    float hw = dc.w / 2, hh = dc.h / 2;
    beginShape(QUADS);
    texture(dc.tex);
    vertex(dc.cx - rx * hw, dc.cy - ry * hw, dc.z + hh, 0, 0);
    vertex(dc.cx + rx * hw, dc.cy + ry * hw, dc.z + hh, 1, 0);
    vertex(dc.cx + rx * hw, dc.cy + ry * hw, dc.z - hh, 1, 1);
    vertex(dc.cx - rx * hw, dc.cy - ry * hw, dc.z - hh, 0, 1);
    endShape();
  }
  flush();
}

// =====================================================================
// POLIWEEK: certificates, arrows and the exit
PImage makeCert() {
  PGraphics g = createGraphics(128, 128);
  g.beginDraw();
  g.clear();
  g.noStroke();
  g.fill(200, 190, 160);
  g.rect(22, 12, 88, 108, 3);
  g.fill(250, 246, 230);
  g.rect(20, 10, 88, 108, 3);
  g.fill(190, 150, 60);
  g.rect(24, 14, 80, 3);
  g.rect(24, 111, 80, 3);
  g.fill(40);
  g.textAlign(CENTER, CENTER);
  g.textSize(11);
  g.text("CERTIFICADO", 64, 28);
  g.textSize(9);
  g.text("2 HORAS", 64, 42);
  g.fill(130);
  for (int k = 0; k < 4; k++) g.rect(32, 56 + k * 9, 64 - (k % 2) * 14, 2);
  g.fill(200, 40, 40);
  g.rect(30, 90, 8, 26);
  g.fill(200, 30, 30, 220);
  g.ellipse(84, 96, 30, 30);
  g.fill(250, 246, 230);
  g.ellipse(84, 96, 20, 20);
  g.fill(200, 30, 30);
  g.textSize(8);
  g.text("OK", 84, 96);
  g.endDraw();
  return g.get();
}

PImage makeExit() {
  PGraphics g = createGraphics(256, 480);
  g.beginDraw();
  g.clear();
  g.noStroke();
  g.fill(20, 150, 60);
  g.rect(28, 6, 200, 72, 6);
  g.fill(225, 255, 225);
  g.textFont(fontUI);
  g.textAlign(CENTER, CENTER);
  g.textSize(46);
  g.text("SAÍDA", 128, 40);
  g.fill(50);
  g.rect(30, 100, 196, 380);
  for (int k = 0; k < 12; k++) {
    g.fill(lerp(200, 255, k / 11.0), 255, lerp(200, 240, k / 11.0));
    g.rect(44 + k * 3, 114 + k * 3, 168 - k * 6, 366 - k * 3);
  }
  g.endDraw();
  return g.get();
}

void placeCerts() {
  for (int k = 0; k < certsPlaced; k++) {
    for (int tries = 0; tries < 900; tries++) {
      int[] c = randomOpenCell();
      boolean relaxed = tries > 600;
      if (flow[c[0]][c[1]] < (relaxed ? 4 : 8)) continue;
      int[] d = DIRS[(int) random(4)];
      if (!wallFace(c[0] + d[0], c[1] + d[1])) continue;
      float x = (c[0] + 0.5) * CELL + d[0] * (CELL * 0.5 - 2.5);
      float y = (c[1] + 0.5) * CELL + d[1] * (CELL * 0.5 - 2.5);
      boolean ok = true;
      for (Cert o : certs) if (dist(o.x, o.y, x, y) < (relaxed ? CELL * 3 : CELL * 7)) ok = false;
      if (!ok) continue;
      Cert ct = new Cert();
      ct.i = c[0];
      ct.j = c[1];
      ct.di = d[0];
      ct.dj = d[1];
      ct.x = x;
      ct.y = y;
      ct.z = 165;
      certs.add(ct);
      break;
    }
  }
}

void updateFuga(float dt) {
  nearCert = -1;
  float fx = cos(yaw), fy = sin(yaw), bestD = 999999;
  for (int k = 0; k < certs.size(); k++) {
    Cert ct = certs.get(k);
    float d = dist(player.x, player.y, ct.x, ct.y);
    if (d > 175) continue;
    float facing = ((ct.x - player.x) * fx + (ct.y - player.y) * fy) / max(d, 1);
    if (facing < 0.35) continue;
    if (d < bestD) {
      bestD = d;
      nearCert = k;
    }
  }
  if (exitOpen && dist(player.x, player.y, exitX(), exitY()) < 150) escapeWin();
}

void collectCert() {
  if (nearCert < 0 || nearCert >= certs.size()) return;
  certs.remove(nearCert);
  nearCert = -1;
  certsTaken++;
  achT = 0;
  stepEnv = 0.3;
  staticBurst = max(staticBurst, 0.2);
  for (Enemy e : enemies) {                     // the ones close enough hear the paper tearing
    if (e.ai == CHASE) continue;
    if (enemies.size() > 1 && enemyPath(e) > 12) continue;
    e.ai = SEARCH;
    e.searchTimer = 0;
    e.senseTimer = 0;
    e.lastSeen.set(player.x, player.y);
  }
  if (!exitOpen && certsTaken >= certsRequired) {
    openExit();
    lastStingMs = -99999;
    triggerSting(enemies.get(0));
    showMsg("A SAÍDA FOI ABERTA!");
  } else {
    String extra = certsTaken > certsRequired ? "  (EXTRA)" : "";
    showMsg("CERTIFICADO DE HORAS  " + certsTaken + "/" + certsPlaced + extra);
  }
}

void placeArrows() {
  arrows.clear();
  for (Cert ct : certs) addArrowsTo(ct.i, ct.j, ARROWS_PER_CERT);
  addArrowsTo(exitI, exitJ, ARROWS_TO_EXIT);
}

void addArrowsTo(int ti, int tj, int count) {
  int[][] f = bfs(ti, tj);
  int placed = 0;
  for (int tries = 0; tries < 800 && placed < count; tries++) {
    int[] c = randomOpenCell();
    int i = c[0], j = c[1];
    if (f[i][j] < 3 || f[i][j] > 16) continue;
    int _open = 0;
    for (int[] d : DIRS) if (!isWall(i + d[0], j + d[1])) _open++;
    if (_open == 4) continue;
    if (_open < 3 && tries < 500) continue;
    int si = 0, sj = 0;
    for (int[] d : DIRS) {
      int ni = i + d[0], nj = j + d[1];
      if (!isWall(ni, nj) && f[ni][nj] == f[i][j] - 1) {
        si = d[0];
        sj = d[1];
        break;
      }
    }
    ArrayList<int[]> walls = new ArrayList<int[]>();
    for (int[] d : DIRS) if (wallFace(i + d[0], j + d[1]) && d[0] * si + d[1] * sj == 0) walls.add(d);
    if (walls.isEmpty()) continue;
    int[] d = walls.get((int) random(walls.size()));
    float cx = (i + 0.5) * CELL + d[0] * (CELL * 0.5 - 3);
    float cy = (j + 0.5) * CELL + d[1] * (CELL * 0.5 - 3);
    boolean tooClose = false;
    for (Arrow o : arrows) if (dist(o.cx, o.cy, cx, cy) < CELL * 2.5) tooClose = true;
    if (tooClose) continue;
    Arrow ar = new Arrow();
    ar.nx = -d[0];
    ar.ny = -d[1];
    ar.cx = cx;
    ar.cy = cy;
    ar.z = random(85, 190);
    ar.size = random(0.8, 1.15);
    ar.tilt = random(-0.18, 0.18);
    float rx = ar.ny, ry = -ar.nx;
    ar.flip = si * rx + sj * ry < 0;
    arrows.add(ar);
    placed++;
  }
}

void drawArrows() {
  if (arrows.isEmpty()) return;
  world.set("emissive", 0.0);
  textureWrap(CLAMP);
  noStroke();
  noTint();
  for (Arrow ar : arrows) {
    if (dist(player.x, player.y, ar.cx, ar.cy) > CELL * 8) continue;
    float hw = 95 * ar.size, hh = 47 * ar.size;
    float ca = cos(ar.tilt), sa = sin(ar.tilt);
    float u0 = ar.flip ? 1 : 0, u1 = ar.flip ? 0 : 1;
    beginShape(QUADS);
    texture(arrowTex);
    arrowVertex(ar, -hw,  hh, ca, sa, u0, 0);
    arrowVertex(ar,  hw,  hh, ca, sa, u1, 0);
    arrowVertex(ar,  hw, -hh, ca, sa, u1, 1);
    arrowVertex(ar, -hw, -hh, ca, sa, u0, 1);
    endShape();
  }
  flush();
}

void arrowVertex(Arrow ar, float px, float pz, float ca, float sa, float u, float v) {
  float qx = px * ca - pz * sa, qz = px * sa + pz * ca;
  float rx = ar.ny, ry = -ar.nx;
  vertex(ar.cx + rx * qx, ar.cy + ry * qx, ar.z + qz, u, v);
}

PImage makeArrow() {
  java.util.Random rng = new java.util.Random(77);
  PGraphics g = createGraphics(512, 256);
  g.beginDraw();
  g.clear();
  float tx = 470, ty = 124;
  for (int k = 0; k < 6; k++) {
    float sx = 30 + rng.nextFloat() * 60;
    float sy = ty + (k - 2.5) * 10 + (rng.nextFloat() - 0.5) * 8;
    sprayStroke(g, sx, sy, tx + (rng.nextFloat() - 0.5) * 8, ty + (rng.nextFloat() - 0.5) * 8, 4 + rng.nextFloat() * 3, rng);
  }
  for (int side = -1; side <= 1; side += 2) {
    for (int k = 0; k < 3; k++) {
      float bx = tx - 115 - rng.nextFloat() * 30;
      float by = ty + side * (62 + rng.nextFloat() * 22);
      sprayStroke(g, bx, by, tx + (rng.nextFloat() - 0.5) * 6, ty + (rng.nextFloat() - 0.5) * 6, 4 + rng.nextFloat() * 2.5, rng);
    }
  }
  g.endDraw();
  return g.get();
}

void sprayStroke(PGraphics g, float x0, float y0, float x1, float y1, float w, java.util.Random rng) {
  int segs = 24;
  float bend = (rng.nextFloat() - 0.5) * 10;
  float nx = -(y1 - y0), ny = x1 - x0;
  float nl = max(0.001, sqrt(nx * nx + ny * ny));
  nx /= nl;
  ny /= nl;
  float px = x0, py = y0;
  g.strokeCap(ROUND);
  for (int s = 1; s <= segs; s++) {
    float t = s / (float) segs;
    float x = lerp(x0, x1, t) + nx * bend * sin(PI * t);
    float y = lerp(y0, y1, t) + ny * bend * sin(PI * t);
    float taper = 0.35 + 0.65 * sin(PI * min(1, t * 1.15));
    g.stroke(32, 26, 20, 150 + rng.nextFloat() * 90);
    g.strokeWeight(w * taper * (0.8 + rng.nextFloat() * 0.4));
    g.line(px, py, x, y);
    px = x;
    py = y;
  }
  g.noStroke();
  for (int k = 0; k < 40; k++) {
    float t = rng.nextFloat();
    float x = lerp(x0, x1, t) + (rng.nextFloat() - 0.5) * w * 4;
    float y = lerp(y0, y1, t) + (rng.nextFloat() - 0.5) * w * 4;
    g.fill(32, 26, 20, 120 + rng.nextFloat() * 100);
    g.ellipse(x, y, 1.5, 1.5);
  }
}

void drawCerts() {
  if (certs.isEmpty()) return;
  world.set("emissive", 0.3 + 0.12 * sin(millis() * 0.004));
  textureWrap(CLAMP);
  noStroke();
  noTint();
  float hw = 48, hh = 48;
  for (Cert ct : certs) {
    if (dist(player.x, player.y, ct.x, ct.y) > CELL * 8) continue;
    float rx = -ct.dj, ry = ct.di;
    beginShape(QUADS);
    texture(certTex);
    vertex(ct.x - rx * hw, ct.y - ry * hw, ct.z + hh, 0, 0);
    vertex(ct.x + rx * hw, ct.y + ry * hw, ct.z + hh, 1, 0);
    vertex(ct.x + rx * hw, ct.y + ry * hw, ct.z - hh, 1, 1);
    vertex(ct.x - rx * hw, ct.y - ry * hw, ct.z - hh, 0, 1);
    endShape();
  }
  flush();
}

void chooseExit() {
  int maxD = 0;
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) maxD = max(maxD, flow[i][j]);
  ArrayList<int[]> cand = new ArrayList<int[]>();
  for (int pass = 0; pass < 2 && cand.isEmpty(); pass++) {
    for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
      if (solid[i][j]) continue;
      if (pass == 0 && flow[i][j] < maxD * 0.7) continue;
      for (int[] d : DIRS) {
        if (!wallFace(i + d[0], j + d[1])) continue;
        boolean taken = false;
        for (Cert ct : certs) if (ct.i == i && ct.j == j && ct.di == d[0] && ct.dj == d[1]) taken = true;
        if (!taken) cand.add(new int[]{i, j, d[0], d[1]});
      }
    }
  }
  int[] c = cand.get((int) random(cand.size()));
  exitI = c[0];
  exitJ = c[1];
  exitDI = c[2];
  exitDJ = c[3];
}

void openExit() {
  exitOpen = true;
}

float exitX() { return (exitI + 0.5) * CELL + exitDI * CELL * 0.25; }
float exitY() { return (exitJ + 0.5) * CELL + exitDJ * CELL * 0.25; }

void drawExit() {
  if (!exitOpen) return;
  world.set("emissive", 1.4 + 0.3 * sin(millis() * 0.005));
  textureWrap(CLAMP);
  noStroke();
  noTint();
  float nx = -exitDI, ny = -exitDJ;
  float rx = ny, ry = -nx;
  float cx = (exitI + 0.5) * CELL + exitDI * (CELL * 0.5 - 3);
  float cy = (exitJ + 0.5) * CELL + exitDJ * (CELL * 0.5 - 3);
  float hw = 110;
  beginShape(QUADS);
  texture(exitTex);
  vertex(cx - rx * hw, cy - ry * hw, 412, 0, 0);
  vertex(cx + rx * hw, cy + ry * hw, 412, 1, 0);
  vertex(cx + rx * hw, cy + ry * hw, 0, 1, 1);
  vertex(cx - rx * hw, cy - ry * hw, 0, 0, 1);
  endShape();
  flush();
}

// =====================================================================
// ITEM ICONS (HUD)
PImage makeItem(int type) {
  java.util.Random rng = new java.util.Random(7 + type);
  PGraphics g = createGraphics(128, 128);
  g.beginDraw();
  g.clear();
  g.strokeJoin(MITER);
  g.stroke(12);
  g.strokeWeight(5);

  if (type == COXINHA) {
    g.fill(200, 192, 170);
    g.quad(10, 100, 114, 92, 120, 122, 6, 124);
    g.noStroke();
    g.fill(140, 110, 60, 150);
    g.ellipse(66, 106, 58, 14);
    g.stroke(12);
    g.fill(214, 140, 50);
    coxinhaShape(g, 64, 60, 0.92);
    g.noStroke();
    g.fill(150, 80, 20, 140);
    g.beginShape();
    g.vertex(66, 16);
    g.bezierVertex(88, 36, 104, 68, 100, 88);
    g.bezierVertex(96, 102, 80, 108, 66, 108);
    g.endShape(CLOSE);
    for (int k = 0; k < 90; k++) {
      float x = 32 + rng.nextFloat() * 64, y = 30 + rng.nextFloat() * 78;
      if (y > 50 && sq((x - 64) / 34.0) + sq((y - 80) / 30.0) > 1) continue;
      if (y <= 50 && abs(x - 64) > (y - 14) * 0.5) continue;
      g.fill(rng.nextFloat() < 0.6 ? color(160, 90, 28) : color(240, 180, 90));
      g.rect(x, y, 3, 3);
    }
    g.noFill();
    g.stroke(12);
    coxinhaShape(g, 64, 60, 0.92);

  } else if (type == SALADA) {
    g.fill(120, 92, 70);                             // the inside of the bowl, behind the heap
    g.ellipse(64, 66, 108, 30);
    g.strokeWeight(3);
    int[][] heap = {{36, 48, 4}, {52, 40, 1}, {67, 36, 0}, {83, 42, 3}, {97, 50, 1},
      {24, 58, 1}, {44, 52, 2}, {62, 50, 4}, {79, 54, 0}, {101, 60, 4},
      {18, 66, 4}, {34, 64, 0}, {52, 64, 3}, {70, 63, 1}, {88, 65, 2}, {108, 66, 1}};
    for (int[] f : heap) {
      float x = f[0], y = f[1];
      if (f[2] == 0) {                               // strawberry
        g.fill(200, 30, 35);
        g.ellipse(x, y, 20, 17);
        g.noStroke();
        g.fill(245, 215, 90);
        for (int k = 0; k < 5; k++) g.rect(x - 6 + rng.nextFloat() * 11, y - 4 + rng.nextFloat() * 8, 2, 2);
        g.fill(60, 140, 40);
        g.triangle(x - 5, y - 9, x + 5, y - 9, x, y - 4);
        g.stroke(12);
      } else if (f[2] == 1) {                        // grape
        g.fill(85, 30, 75);
        g.ellipse(x, y, 14, 16);
        g.noStroke();
        g.fill(160, 110, 150);
        g.ellipse(x - 2, y - 3, 4, 5);
        g.stroke(12);
      } else if (f[2] == 2) {                        // banana slice
        g.fill(245, 232, 170);
        g.ellipse(x, y, 18, 16);
        g.noStroke();
        g.fill(215, 190, 110);
        g.ellipse(x, y, 6, 5);
        g.stroke(12);
      } else if (f[2] == 3) {                        // kiwi
        g.fill(110, 160, 45);
        g.ellipse(x, y, 19, 17);
        g.noStroke();
        g.fill(215, 230, 160);
        g.ellipse(x, y, 7, 6);
        g.fill(20);
        for (int k = 0; k < 8; k++) g.rect(x + cos(k * 0.785) * 5.5 - 1, y + sin(k * 0.785) * 4.5 - 1, 2, 2);
        g.stroke(12);
      } else {                                       // mango / papaya cube
        g.fill(240, 145, 35);
        g.pushMatrix();
        g.translate(x, y);
        g.rotate(x * 0.07);
        g.rect(-7, -7, 14, 14, 3);
        g.popMatrix();
      }
    }
    g.strokeWeight(5);
    g.fill(214, 196, 168);                           // the bowl, ridged like the model's
    g.beginShape();
    g.vertex(10, 66);
    g.bezierVertex(12, 102, 40, 114, 64, 114);
    g.bezierVertex(88, 114, 116, 102, 118, 66);
    g.bezierVertex(100, 76, 28, 76, 10, 66);
    g.endShape(CLOSE);
    g.fill(190, 170, 140);
    g.rect(46, 112, 36, 9, 3);
    g.noFill();
    g.strokeWeight(2);
    g.stroke(160, 138, 110);
    for (int k = 0; k < 3; k++) {
      float y = 84 + k * 9, w = 50 - k * 7;
      g.bezier(64 - w, y, 64 - w * 0.4, y + 7, 64 + w * 0.4, y + 7, 64 + w, y);
    }
    g.stroke(12);
    g.strokeWeight(5);
    g.noFill();
    g.beginShape();
    g.vertex(10, 66);
    g.bezierVertex(12, 102, 40, 114, 64, 114);
    g.bezierVertex(88, 114, 116, 102, 118, 66);
    g.endShape();
    g.strokeWeight(4);
    g.bezier(10, 66, 28, 76, 100, 76, 118, 66);

  } else if (type == LAGRIMAS) {
    g.fill(110, 130, 110, 210);
    g.rect(36, 40, 56, 80);
    g.rect(52, 20, 24, 22);
    g.noStroke();
    g.fill(35, 100, 215);
    g.rect(40, 64, 48, 52);
    g.fill(70, 150, 255);
    g.rect(40, 64, 48, 6);
    g.fill(125, 12, 12);
    g.rect(48, 6, 32, 16);
    g.rect(50, 20, 6, 12);
    g.rect(70, 20, 5, 8);
    g.fill(210, 190, 135);
    g.pushMatrix();
    g.translate(64, 88);
    g.rotate(-0.08);
    g.rect(-24, -12, 48, 24);
    g.fill(25);
    g.textSize(13);
    g.textAlign(CENTER, CENTER);
    g.text("LC", 0, -1);
    g.popMatrix();
    g.stroke(225, 230, 225);
    g.strokeWeight(3);
    g.line(44, 46, 44, 110);
    g.stroke(12);
    g.strokeWeight(5);
    g.noFill();
    g.rect(36, 40, 56, 80);
    g.rect(52, 20, 24, 22);
    g.rect(48, 6, 32, 16);

  } else if (type == CESTA) {
    g.fill(236, 234, 226);
    g.rect(24, 16, 32, 48);
    g.fill(30, 70, 160);
    g.rect(24, 30, 32, 12);
    g.fill(225, 170, 20);
    g.rect(60, 6, 16, 56);
    g.fill(170, 20, 15);
    g.rect(62, 0, 12, 8);
    g.fill(120, 20, 15);
    g.rect(80, 22, 26, 40);
    g.fill(168, 122, 72);
    g.quad(12, 56, 0, 38, 30, 38, 38, 56);
    g.quad(116, 56, 128, 38, 98, 38, 90, 56);
    g.rect(12, 56, 104, 66);
    g.noStroke();
    g.fill(205, 185, 135, 220);
    g.rect(56, 56, 16, 66);
    g.fill(150, 20, 15);
    g.rect(20, 74, 30, 14);
    g.fill(235);
    g.textSize(8);
    g.textAlign(CENTER, CENTER);
    g.text("CESTA", 35, 80);
    for (int k = 0; k < 6; k++) {
      g.fill(90, 60, 30, 90);
      g.ellipse(20 + rng.nextFloat() * 88, 64 + rng.nextFloat() * 54, 10 + rng.nextFloat() * 18, 6 + rng.nextFloat() * 10);
    }
    g.stroke(12);
    g.strokeWeight(5);
    g.noFill();
    g.rect(12, 56, 104, 66);

  } else if (type == TASER) {
    g.fill(32);
    taserShape(g);
    g.noStroke();
    g.fill(230, 175, 20);
    g.rect(18, 50, 40, 26);
    g.fill(12);
    for (int k = 0; k < 4; k++) g.quad(18 + k * 10, 76, 24 + k * 10, 76, 34 + k * 10, 50, 28 + k * 10, 50);
    g.fill(55);
    for (int k = 0; k < 4; k++) g.rect(34, 90 + k * 8, 20, 3);
    g.fill(60, 220, 60);
    g.rect(88, 50, 7, 7);
    g.fill(175);
    g.rect(110, 52, 14, 7);
    g.rect(110, 72, 14, 7);
    g.stroke(120, 200, 255);
    g.strokeWeight(3);
    g.line(122, 59, 116, 65);
    g.line(116, 65, 124, 69);
    g.line(124, 69, 120, 73);
    g.stroke(12);
    g.strokeWeight(5);
    g.noFill();
    taserShape(g);

  } else if (type == MONSTER) {
    g.pushMatrix();
    g.translate(64, 68);
    g.fill(234, 232, 224);
    g.rect(-25, -48, 50, 96, 5);
    g.fill(178, 181, 188);
    g.rect(-21, -57, 42, 10, 3);
    g.rect(-21, 46, 42, 8, 3);
    g.strokeWeight(3);
    g.fill(150, 152, 162);
    for (int k = -1; k <= 1; k++) {                  // the three claw marks
      float cx = k * 12, len = k == 0 ? 34 : 26;
      g.beginShape();
      g.vertex(cx - 5, -34); g.vertex(cx + 5, -34); g.vertex(cx + 2, -8);
      g.vertex(cx + 4, len - 8); g.vertex(cx, len); g.vertex(cx - 3, -6);
      g.endShape(CLOSE);
    }
    g.line(-20, -36, 20, -36);
    g.noStroke();
    g.fill(150, 210, 255, 170);                      // cold sweat
    for (int k = 0; k < 7; k++) g.ellipse(-20 + rng.nextFloat() * 40, -40 + rng.nextFloat() * 80, 3, 5);
    g.stroke(12);
    g.popMatrix();

  } else if (type == LATA) {                         // stomped flat: the lid tilted on top of a crumpled body
    g.fill(178, 181, 188);
    g.ellipse(64, 104, 88, 20);
    g.fill(234, 232, 224);
    g.beginShape();
    g.vertex(14, 62); g.vertex(26, 56); g.vertex(40, 63); g.vertex(56, 55); g.vertex(74, 62); g.vertex(92, 53);
    g.vertex(112, 59); g.vertex(119, 75); g.vertex(110, 85); g.vertex(117, 96); g.vertex(98, 106); g.vertex(70, 109);
    g.vertex(44, 106); g.vertex(22, 102); g.vertex(9, 90); g.vertex(17, 80);
    g.endShape(CLOSE);
    g.strokeWeight(3);
    g.fill(150, 152, 162);
    for (int k = -1; k <= 1; k++) {                  // the claw marks, squashed
      float cx = 64 + k * 15;
      g.beginShape();
      g.vertex(cx - 6, 66); g.vertex(cx + 6, 66); g.vertex(cx + 2, 78); g.vertex(cx + 7, 86);
      g.vertex(cx + 1, 100 - abs(k) * 4); g.vertex(cx - 2, 86); g.vertex(cx - 7, 78);
      g.endShape(CLOSE);
    }
    g.noFill();
    g.stroke(120, 120, 128);
    g.beginShape();                                  // the folds
    g.vertex(17, 80); g.vertex(36, 74); g.vertex(54, 84); g.vertex(76, 76); g.vertex(96, 83); g.vertex(110, 85);
    g.endShape();
    g.beginShape();
    g.vertex(22, 96); g.vertex(44, 90); g.vertex(66, 98); g.vertex(88, 91); g.vertex(106, 98);
    g.endShape();
    g.stroke(12);
    g.strokeWeight(5);
    g.pushMatrix();
    g.translate(64, 48);
    g.rotate(-0.12);
    g.fill(178, 181, 188);
    g.ellipse(0, 0, 94, 36);
    g.strokeWeight(3);
    g.fill(205, 207, 213);
    g.ellipse(0, 1, 74, 26);
    g.fill(20);
    g.ellipse(-12, 0, 24, 9);
    g.fill(190, 192, 198);                           // the pull tab
    g.ellipse(9, -1, 26, 11);
    g.fill(120);
    g.ellipse(13, -1, 9, 5);
    g.popMatrix();
  }
  g.endDraw();
  roughen(g, rng);
  return g.get();
}

void taserShape(PGraphics g) {
  g.beginShape();
  g.vertex(12, 44); g.vertex(100, 44); g.vertex(110, 54); g.vertex(110, 82); g.vertex(62, 82);
  g.vertex(54, 122); g.vertex(26, 122); g.vertex(32, 82); g.vertex(12, 82);
  g.endShape(CLOSE);
}

void coxinhaShape(PGraphics g, float cx, float cy, float s) {
  g.beginShape();
  g.vertex(cx, cy - 50 * s);
  g.bezierVertex(cx + 22 * s, cy - 30 * s, cx + 46 * s, cy + 10 * s, cx + 40 * s, cy + 34 * s);
  g.bezierVertex(cx + 34 * s, cy + 54 * s, cx - 34 * s, cy + 54 * s, cx - 40 * s, cy + 34 * s);
  g.bezierVertex(cx - 46 * s, cy + 10 * s, cx - 22 * s, cy - 30 * s, cx, cy - 50 * s);
  g.endShape(CLOSE);
}

void roughen(PGraphics g, java.util.Random rng) {
  g.loadPixels();
  for (int p = 0; p < g.pixels.length; p++) {
    int c = g.pixels[p];
    int a = (c >>> 24) & 255;
    if (a == 0) continue;
    float k = 0.78 + rng.nextFloat() * 0.22;
    if (rng.nextFloat() < 0.04) k *= 0.45;
    float r = ((c >> 16) & 255), gg = ((c >> 8) & 255), b = (c & 255);
    float l = (r + gg + b) / 3.0;
    r = lerp(r, l, 0.15) * k;
    gg = lerp(gg, l, 0.15) * k;
    b = lerp(b, l, 0.15) * k;
    g.pixels[p] = (a << 24) | ((int) r << 16) | ((int) gg << 8) | (int) b;
  }
  g.updatePixels();
}

// =====================================================================
// 3D ITEM MODELS
PShape[] coxModels = new PShape[3];   // whole, one bite, bitten down to the filling
float[] coxTop = {124, 107, 96};
PShape saladaModel, lagrimasModel, cestaModel, taserModel, lataModel;
PImage lagrimasLabel;

void initModels() {
  coxModels[0] = loadItem("item_coxinha.obj");
  coxModels[1] = loadItem("item_coxinha_mordida.obj");
  coxModels[2] = loadItem("item_coxinha_centro.obj");
  saladaModel = loadItem("item_salada.obj");
  lagrimasModel = loadItem("item_lagrimas.obj");
  lagrimasModel.removeChild(lagrimasModel.getChildIndex(lagrimasModel.getChild("water_lable")));   // our own label goes on instead
  lagrimasLabel = makeLagrimasLabel();
  cestaModel = loadItem("item_cesta.obj");
  taserModel = loadItem("item_taser.obj");
  lataModel = loadItem("item_lata.obj");      // the empty Monster, stomped flat
}

// an OBJ already baked in game units (y down, base at y = 0): one triangle mesh per material of its .mtl.
// A material with d < 1 is see-through plastic: named "glass" so drawItem draws it without writing depth
PShape loadItem(String file) {
  HashMap<String, String[]> mtl = new HashMap<String, String[]>();
  String[] cur = null;
  for (String ln : loadStrings(file.substring(0, file.length() - 4) + ".mtl")) {
    String[] p = splitTokens(ln);
    if (p.length == 0) continue;
    if (p[0].equals("newmtl")) {
      cur = new String[]{"1", "1", "1", "1", "10", null};    // Kd r g b, d, Ns, map_Kd
      mtl.put(p[1], cur);
    } else if (cur == null) continue;
    else if (p[0].equals("Kd")) arrayCopy(p, 1, cur, 0, 3);
    else if (p[0].equals("d")) cur[3] = p[1];
    else if (p[0].equals("Ns")) cur[4] = p[1];
    else if (p[0].equals("map_Kd")) cur[5] = p[1];
  }
  ArrayList<PVector> vs = new ArrayList<PVector>(), vt = new ArrayList<PVector>(), vn = new ArrayList<PVector>();
  PShape grp = createShape(GROUP);
  PShape sh = null;
  for (String ln : loadStrings(file)) {
    String[] p = splitTokens(ln);
    if (p.length == 0) continue;
    if (p[0].equals("v")) vs.add(new PVector(float(p[1]), float(p[2]), float(p[3])));
    else if (p[0].equals("vt")) vt.add(new PVector(float(p[1]), 1 - float(p[2])));
    else if (p[0].equals("vn")) vn.add(new PVector(-float(p[1]), -float(p[2]), -float(p[3])));   // P3D lights them from the other side
    else if (p[0].equals("usemtl")) {
      if (sh != null) {
        sh.endShape();
        grp.addChild(sh);
      }
      String[] m = mtl.get(p[1]);
      sh = createShape();
      sh.beginShape(TRIANGLES);
      sh.noStroke();
      float d = float(m[3]);
      if (m[5] != null) sh.texture(loadImage(m[5]));
      sh.setName(d < 1 ? "glass" : p[1]);
      sh.fill(255 * float(m[0]), 255 * float(m[1]), 255 * float(m[2]), 255 * d);
      sh.specular(constrain(float(m[4]) * 2, 0, 200));
      sh.shininess(max(1, float(m[4]) / 4));
    } else if (p[0].equals("f") && sh != null) {
      for (int a = 1; a <= 3; a++) {
        String[] ix = split(p[a], '/');
        PVector v = vs.get(int(ix[0]) - 1);
        PVector nn = vn.get(int(ix[2]) - 1);
        sh.normal(nn.x, nn.y, nn.z);
        if (ix[1].length() > 0) {
          PVector t = vt.get(int(ix[1]) - 1);
          sh.vertex(v.x, v.y, v.z, t.x, t.y);
        } else {
          sh.vertex(v.x, v.y, v.z);
        }
      }
    }
  }
  if (sh != null) {
    sh.endShape();
    grp.addChild(sh);
  }
  return grp;
}

void drawItem(PShape grp) {
  for (PShape ch : grp.getChildren()) {
    boolean glass = "glass".equals(ch.getName());
    if (glass) hint(DISABLE_DEPTH_MASK);
    shape(ch);
    if (glass) hint(ENABLE_DEPTH_MASK);
  }
}
void lathe(float[] r, float[] h, int n, int segs, int cBot, int cTop, float grain) {
  float hMin = h[0], hMax = h[n - 1];
  float span = max(0.001, hMax - hMin);
  float[] nr = new float[n], nh = new float[n];
  for (int k = 0; k < n; k++) {
    float dr = r[min(n - 1, k + 1)] - r[max(0, k - 1)];
    float dh = h[min(n - 1, k + 1)] - h[max(0, k - 1)];
    float len = max(0.0001, sqrt(dr * dr + dh * dh));
    nr[k] = dh / len;
    nh[k] = -dr / len;
  }
  beginShape(QUADS);
  for (int k = 0; k < n - 1; k++) {
    int ca = lerpColor(cBot, cTop, constrain((h[k] - hMin) / span, 0, 1));
    int cb = lerpColor(cBot, cTop, constrain((h[k + 1] - hMin) / span, 0, 1));
    for (int s = 0; s < segs; s++) {
      float a0 = TWO_PI * s / segs, a1 = TWO_PI * (s + 1) / segs;
      lv(r[k], h[k], a0, nr[k], nh[k], ca, grain);
      lv(r[k], h[k], a1, nr[k], nh[k], ca, grain);
      lv(r[k + 1], h[k + 1], a1, nr[k + 1], nh[k + 1], cb, grain);
      lv(r[k + 1], h[k + 1], a0, nr[k + 1], nh[k + 1], cb, grain);
    }
  }
  endShape();
}

void lv(float r, float h, float a, float nr, float nh, int c, float grain) {
  float x = r * cos(a), z = r * sin(a);
  if (grain > 0) {
    int dark = color(red(c) * 0.35, green(c) * 0.3, blue(c) * 0.25, alpha(c));
    c = lerpColor(c, dark, grain * noise(x * 0.15 + 50, h * 0.15, z * 0.15));
  }
  fill(c);
  normal(nr * cos(a), -nh, nr * sin(a));
  vertex(x, -h, z);
}

void disc(float r, float h, int segs, int c) {
  beginShape(TRIANGLES);
  for (int s = 0; s < segs; s++) {
    float a0 = TWO_PI * s / segs, a1 = TWO_PI * (s + 1) / segs;
    fill(c);
    normal(0, -1, 0);
    vertex(0, -h, 0);
    vertex(r * cos(a0), -h, r * sin(a0));
    vertex(r * cos(a1), -h, r * sin(a1));
  }
  endShape();
}

// each bite swaps to the next model, right after the chomp lands
float modelCoxinha(float c) {
  int stage = min(2, floor(c * 3));
  drawItem(coxModels[stage]);
  return coxTop[stage];
}

float modelSalada(float c) {
  drawItem(saladaModel);
  return 84;
}

// the tears glow inside the bottle and drain as you drink
float modelLagrimas(float c) {
  float lvl = 6 + 92 * (1 - c);
  emissive(10, 35, 95);
  lathe(new float[]{0, 15.2, 15.2, 0}, new float[]{4, 4, lvl, lvl}, 4, 20, color(35, 95, 215), color(70, 145, 255), 0);
  emissive(0);
  specular(60);
  shininess(10);
  beginShape(QUAD_STRIP);                       // the label: a band around the bottle's waist
  texture(lagrimasLabel);
  fill(255);
  for (int k = 0; k <= 40; k++) {
    float a = TWO_PI * k / 40;
    normal(cos(a), 0, sin(a));
    vertex(17.1 * cos(a), -84, 17.1 * sin(a), 1 - k / 40.0, 0);
    vertex(17.1 * cos(a), -52, 17.1 * sin(a), 1 - k / 40.0, 1);
  }
  endShape();
  specular(0);
  drawItem(lagrimasModel);
  return 128;
}

// "LC — Lágrimas do Cabral", twice around the bottle so it reads from any side
PImage makeLagrimasLabel() {
  PGraphics g = createGraphics(1024, 300);
  g.beginDraw();
  for (int y = 0; y < g.height; y++) {
    g.stroke(lerpColor(color(165, 222, 248), color(55, 140, 210), y / (float) g.height));
    g.line(0, y, g.width, y);
  }
  g.noStroke();
  java.util.Random rng = new java.util.Random(11);
  for (int k = 0; k < 40; k++) {                // tears running down
    float x = rng.nextFloat() * g.width, y = rng.nextFloat() * g.height, r = 5 + rng.nextFloat() * 9;
    g.fill(255, 90 + rng.nextFloat() * 80);
    g.ellipse(x, y, r * 2, r * 2);
    g.triangle(x - r * 0.85, y - r * 0.5, x + r * 0.85, y - r * 0.5, x, y - r * 2.6);
  }
  for (int p = 0; p < 2; p++) {
    float x0 = p * 512;
    g.fill(15, 45, 95);
    g.ellipse(x0 + 105, 150, 170, 170);
    g.noFill();
    g.stroke(255);
    g.strokeWeight(6);
    g.ellipse(x0 + 105, 150, 146, 146);
    g.noStroke();
    g.fill(255);
    g.textFont(fontBig);
    g.textAlign(CENTER, CENTER);
    g.textSize(86);
    g.text("LC", x0 + 105, 140);
    g.fill(15, 45, 95);
    g.textAlign(LEFT, CENTER);
    g.textSize(62);
    g.text("LÁGRIMAS", x0 + 205, 108);
    g.textSize(44);
    g.text("DO CABRAL", x0 + 207, 172);
    g.fill(255);
    g.textSize(20);
    g.text("100% CHORO MINERAL", x0 + 209, 222);
  }
  g.endDraw();
  return g.get();
}

float modelCesta(float c) {
  drawItem(cestaModel);
  return 78;
}

void modelTaser(boolean firing) {
  drawItem(taserModel);
  if (firing) {
    emissive(80, 160, 255);
    fill(170, 215, 255);
    pushMatrix(); translate(0, 2, -68); sphere(7); popMatrix();
    for (int k = 0; k < 3; k++) {
      pushMatrix();
      translate(random(-8, 8), 2 + random(-4, 4), -68 + random(-3, 3));
      box(2);
      popMatrix();
    }
    emissive(0);
  }
  specular(0);
  tipSX = screenX(0, 2, -68);
  tipSY = screenY(0, 2, -68);
}
float drawModel(int type, float c, boolean firing) {
  if (type == COXINHA) return modelCoxinha(c);
  if (type == SALADA) return modelSalada(c);
  if (type == LAGRIMAS) return modelLagrimas(c);
  if (type == CESTA) return modelCesta(c);
  if (type == MONSTER) return modelCan();
  if (type == LATA) return modelLata();
  modelTaser(firing);
  return 30;
}

void drawDrops3D() {
  sphereDetail(8);
  noStroke();
  float t = millis() / 1000.0;
  float maxD = CELL * 5.5;
  for (Drop dr : drops) {
    float dd = dist(player.x, player.y, dr.x, dr.y);
    if (dd > maxD) continue;
    float vis = exp(-pow(dd / FOG_DIST, 1.5));
    float appear = constrain((maxD - dd) / (CELL * 0.8), 0, 1);
    float ph = dr.x * 0.013 + dr.y * 0.007;
    float bob = sin(t * 2.2 + ph);
    float up01 = bob * 0.5 + 0.5;
    float hover = 30 + bob * 9;
    float sc = (dr.type == CESTA ? 0.55 : 0.6) * appear;

    if (dd < CELL * 4) {
      noLights();
      float sa = 55 * sq(vis) * (1 - dd / (CELL * 4)) * (1 - 0.35 * up01) * appear;
      float sr = (dr.type == CESTA ? 70 : 55) * (1 - 0.15 * up01);
      pushMatrix();
      translate(dr.x, dr.y, 2.5);
      for (int k = 0; k < 3; k++) {
        fill(0, sa / 3);
        ellipse(0, 0, sr * (1 - k * 0.25), sr * (1 - k * 0.25));
      }
      popMatrix();
    }

    itemLights(dr.x, dr.y, lerp(1, vis, 0.5));

    pushMatrix();
    translate(dr.x, dr.y, hover + (dr.type == TASER ? 60 * sc : 0));
    rotateZ(t * 1.3 + ph);
    rotateX(-HALF_PI);
    rotateZ(sin(t * 1.7 + ph) * 0.12);
    scale(sc);
    drawModel(dr.type, 0, false);
    popMatrix();
    flush();
  }
  noLights();
  lightFalloff(1, 0, 0);
  specular(0);
  emissive(0);
}

// the room's lamp + your flashlight on a small object at (x, y); L dims it with the fog
void itemLights(float x, float y, float L) {
  int ci = cellOf(x), cj = cellOf(y);
  float lp = lampP[ci][cj];
  float amb = (0.3 + 0.5 * lp) * L;
  noLights();
  lightFalloff(1, 0, 0);
  ambientLight(70 * amb, 62 * amb, 48 * amb);
  lightFalloff(1, 0, 0.000004);
  pointLight(255 * lp * L, 235 * lp * L, 185 * lp * L, (ci + 0.5) * CELL, (cj + 0.5) * CELL, WALL_H - 25);
  lightFalloff(1, 0, 0);
  if (flashlightOn) spotLight(210 * flicker * L, 220 * flicker * L, 235 * flicker * L,
    camX, camY, camZ, camDX, camDY, camDZ, radians(30), 2);
}

void drawViewModel3D() {
  int now = millis();
  boolean firing = now < fireUntil;
  if (useType < 0 && inv[TASER] <= 0 && !firing) return;

  PGL pgl = beginPGL();
  pgl.clear(PGL.DEPTH_BUFFER_BIT);
  endPGL();
  perspective(radians(55), float(width) / height, 1, 3000);
  camera(0, 0, 0, 0, 0, -1, 0, 1, 0);

  float lvl = constrain(localLight + (flashlightOn ? 0.35 * flicker : 0), 0.12, 1.3);
  ambientLight(60 * lvl, 54 * lvl, 42 * lvl);
  lightSpecular(140 * lvl, 130 * lvl, 110 * lvl);
  directionalLight(255 * lvl, 236 * lvl, 190 * lvl, -0.25, 0.75, -0.6);
  lightSpecular(0, 0, 0);
  directionalLight(40, 45, 60, 0.6, -0.3, -0.4);
  noStroke();
  sphereDetail(10);

  float bobX = cos(bobPhase) * 4, bobY = abs(sin(bobPhase)) * 4;
  if (useType >= 0) {
    float t = constrain((now - useStart) / (float) USE_MS[useType], 0, 1);
    float up = t < 0.2 ? t / 0.2 : (t > 0.85 ? 1 - (t - 0.85) / 0.15 : 1);
    up = up * up * (3 - 2 * up);
    float c = constrain((t - 0.2) / 0.65, 0, 1);
    boolean eatingNow = c > 0 && c < 1;
    float topH;
    pushMatrix();
    if (useType == LAGRIMAS || useType == MONSTER) {
      float tilt = up * (0.25 + 1.25 * min(1, c * 2));
      translate(30 + bobX, lerp(240, 40, up) + bobY - 25 * tilt, -210 + 40 * tilt);
      rotateZ(-0.25 * up);
      rotateX(-tilt);
      if (useType == MONSTER) rotateY(PI - 0.3);   // the logo toward you
      topH = useType == MONSTER ? modelCan() : modelLagrimas(c);
    } else {
      float chomp = eatingNow ? pow(abs(sin(c * PI * 6)), 3) : 0;
      translate(bobX, lerp(250, useType == CESTA ? 75 : 60, up) + bobY - chomp * 10, -250 + 70 * chomp);
      rotateX(useType == CESTA ? -0.55 : -0.3);
      rotateY(now * 0.0006 + c * 1.5);
      topH = drawModel(useType, c, false);
    }
    biteSX = screenX(0, -topH, 0);
    biteSY = screenY(0, -topH, 0);
    popMatrix();
  } else {
    float k = firing ? 1 - (fireUntil - now) / 350.0 : 0;
    float recoil = firing ? sin(k * PI) : 0;
    pushMatrix();
    translate(120 + bobX, 55 + bobY - recoil * 8, -230 + recoil * 25);
    rotateY(0.3);
    rotateX(recoil * 0.35);
    modelTaser(firing);
    popMatrix();
  }
  flush();
  noLights();
  specular(0);
  emissive(0);
}

// =====================================================================
// DROPS, ITEMS AND BUFFS
void spawnDrop() {
  int type = nextDropType();
  for (int tries = 0; tries < 200; tries++) {
    int[] c = randomOpenCell();
    if (flow[c[0]][c[1]] < 5) continue;
    float x = (c[0] + 0.5) * CELL + random(-60, 60), y = (c[1] + 0.5) * CELL + random(-60, 60);
    boolean ok = true;
    for (Drop dr : drops) if (dist(dr.x, dr.y, x, y) < CELL * 2.5) ok = false;
    if (ok) {
      drops.add(new Drop(x, y, type));
      return;
    }
  }
}

int nextDropType() {
  for (int guard = 0; guard < 40; guard++) {
    if (dropBag.isEmpty()) {
      for (int k = 0; k < DROP_BAG.length; k++) for (int n = 0; n < DROP_BAG[k]; n++) dropBag.add(k);
      java.util.Collections.shuffle(dropBag);
    }
    int t = dropBag.remove(dropBag.size() - 1);
    if (t == TASER && (survived < TASER_UNLOCK || tasersOnMap() > 0)) {
      dropBag.add(0, t);
      continue;
    }
    return t;
  }
  return (int) random(4);
}

int tasersOnMap() {
  int n = 0;
  for (Drop dr : drops) if (dr.type == TASER) n++;
  return n;
}

float staminaMax() {
  return STAMINA_MAX * pizzaMul() * (millis() < fedUntil ? 2 : 1);
}

void startUse(int type) {
  if (type < 0 || type == TASER || type == LATA || inv[type] <= 0 || useType >= 0) return;
  inv[type]--;
  useType = type;
  useStart = millis();
  chewTimer = 0;
}

// every chaser loses you on the spot and goes to search where you vanished
boolean vanish() {
  boolean any = false;
  for (Enemy e : enemies) {
    if (e.ai != CHASE) continue;
    e.ai = SEARCH;
    e.searchTimer = e.lostTimer = 0;
    e.lastSeen.set(player.x, player.y);
    e.goalI = -1;
    e.sees = false;
    chasesEscaped++;
    any = true;
  }
  if (any) {
    unlock(21);
    if (chasesEscaped >= 8) unlock(9);
  }
  return any;
}

void applyBuff(int type) {
  int now = millis();
  itemsUsed++;
  usedType[type] = true;
  usedCount[type]++;
  switch (type) {
  case COXINHA:
    energyUntil = now + BUFF_MS[COXINHA];
    exhausted = false;
    showMsg("ENERGIA  —  CORRIDA INFINITA");
    if (usedCount[COXINHA] >= 3) unlock(3);
    break;
  case SALADA:
    swiftUntil = now + BUFF_MS[SALADA];
    showMsg("LEVEZA  —  VOCÊ ESTÁ MAIS RÁPIDO");
    break;
  case LAGRIMAS:
    ghostUntil = now + BUFF_MS[LAGRIMAS];
    showMsg(vanish() ? "INVISÍVEL  —  ELES TE PERDERAM" : "INVISÍVEL  —  ELES NÃO TE VEEM");
    break;
  case CESTA:
    fedUntil = now + BUFF_MS[CESTA];
    stamina = STAMINA_MAX * 2 * pizzaMul();
    exhausted = false;
    showMsg("ABASTECIDO  —  FÔLEGO EM DOBRO");
    break;
  case MONSTER:
    pilhadoUntil = now + BUFF_MS[MONSTER];
    if (inv[LATA] < MAX_STACK) inv[LATA]++;
    itemSeen[LATA] = true;
    showMsg("PILHADO  —  VOCÊ OS VÊ ATRAVÉS DAS PAREDES   ·   + LATA VAZIA [G]");
    break;
  }
  if (usedType[0] && usedType[1] && usedType[2] && usedType[3] && survived <= 120) unlock(4);
}

void fireTaser() {
  if (inv[TASER] <= 0 || useType >= 0 || millis() < fireUntil) return;
  inv[TASER]--;
  tasersFired++;
  fireUntil = millis() + 350;
  Enemy target = null;
  float bestF = 0.85, targetD = 0;
  for (Enemy e : enemies) {
    float d = dist(player.x, player.y, e.pos.x, e.pos.y);
    float facing = ((e.pos.x - player.x) * cos(yaw) + (e.pos.y - player.y) * sin(yaw)) / max(d, 1);
    if (d < TASER_RANGE && facing > bestF && lineOfSight(player.x, player.y, e.pos.x, e.pos.y)) {
      bestF = facing;
      target = e;
      targetD = d;
    }
  }
  taserHit = target != null;
  boltEnemy = target;
  staticBurst = 0.45;
  stepEnv = 0.4;
  if (taserHit) stunEnemy(target, targetD);
  else showMsg("ERROU  —  O TASER DESCARREGOU");
}

void stunEnemy(Enemy e, float d) {
  stuns++;
  if (stuns >= 3) unlock(7);
  if (d < CELL * 0.5) unlock(12);
  if (e.ai == CHASE) {
    chasesEscaped++;
    if (chasesEscaped >= 8) unlock(9);
  }
  e.stunUntil = millis() + (int) (STUN_MS * STUN_MUL[e.ch]);
  e.confusedUntil = e.stunUntil + (int) (CONFUSE_MS * STUN_MUL[e.ch]);
  e.ai = WANDER;
  e.sees = false;
  e.lostTimer = e.searchTimer = e.senseTimer = e.chaseTime = 0;
  pickWanderFar(e);
  showMsg("ATORDOADO  —  " + NAMES[e.ch].toUpperCase() + " TE PERDEU");
}

// =====================================================================
// UPDATE
void update(float dt) {
  survived = (millis() - startMs) / 1000.0;
  int now = millis();
  if (!focused) releaseKeys();

  float fx = cos(yaw), fy = sin(yaw);
  float rx = -fy, ry = fx;
  float mx = 0, my = 0;
  if (kUp)    { mx += fx; my += fy; }
  if (kDown)  { mx -= fx; my -= fy; }
  if (kRight) { mx += rx; my += ry; }
  if (kLeft)  { mx -= rx; my -= ry; }

  // ---- peeking: hold Q/E at a corner; the body stays put while the head leans out
  if ((peekSide < 0 && !keyDown['Q']) || (peekSide > 0 && !keyDown['E'])) peekSide = 0;
  if (peekSide != 0) {
    mx = my = 0;
    float room = leanRoom(peekSide);
    peekOff.set(-sin(yaw) * peekSide * room, cos(yaw) * peekSide * room);
  }
  peekAmt = lerp(peekAmt, peekSide != 0 ? 1 : 0, 1 - exp(-dt * 7));
  peekL = peekSide == 0 ? findCorner(-1) : null;
  peekR = peekSide == 0 ? findCorner(1) : null;

  float len = sqrt(mx * mx + my * my);
  moving = len > 0;

  if (crouchToggle && kSprint && moving) crouchToggle = false;
  crouching = crouchToggle || kCrouch;

  boolean energized = now < energyUntil;
  boolean fed = now < fedUntil;
  float smax = staminaMax();
  sprinting = moving && kSprint && !crouching && useType < 0 && !exhausted && (stamina > 0 || energized);
  if (energized) stamina = smax;
  else if (sprinting) stamina = max(0, stamina - dt);
  else stamina = min(smax, stamina + dt * 0.6 * (fed ? 3 : 1));
  stamina = min(stamina, smax);
  if (stamina <= 0) exhausted = true;
  if (exhausted && stamina >= smax * 0.35) exhausted = false;

  if (sprinting) sprintTime += dt;
  if (!flashlightOn) darkTime += dt;
  darkStreak = flashlightOn ? 0 : darkStreak + dt;

  eyeH = lerp(eyeH, crouching ? CROUCH_EYE : EYE_H, 1 - exp(-dt * 10));

  float px0 = player.x, py0 = player.y;
  if (moving) {
    float speed = crouching ? CROUCH_SPEED : (sprinting ? SPRINT_SPEED : WALK_SPEED);
    if (now < swiftUntil) speed *= 1.25;
    if (useType >= 0) speed *= 0.6;
    float step = speed * dt / len;
    float nx = player.x + mx * step, ny = player.y + my * step;
    if (!hitsWall(nx, player.y)) player.x = nx;
    if (!hitsWall(player.x, ny)) player.y = ny;
    bobPhase += dt * (crouching ? 6 : (sprinting ? 14 : 9));
    int st = floor((bobPhase - HALF_PI) / PI);
    if (st != lastStep) {
      lastStep = st;
      stepEnv = crouching ? 0.08 : (sprinting ? 0.6 : 0.35);
    }
  } else {
    bobPhase = lerp(bobPhase, round(bobPhase / PI) * PI, 1 - exp(-dt * 8));
  }
  if (dt > 0) {
    pvx = lerp(pvx, (player.x - px0) / dt, 0.15);
    pvy = lerp(pvy, (player.y - py0) / dt, 0.15);
  }

  int vci = cellOf(player.x), vcj = cellOf(player.y);
  if (!visited[vci][vcj]) {
    visited[vci][vcj] = true;
    visitedCount++;
  }

  if (useType >= 0) {
    float t = (now - useStart) / (float) USE_MS[useType];
    if (t >= 1) {
      applyBuff(useType);
      useType = -1;
    } else if (t > 0.2 && t < 0.85) {
      chewTimer += dt;
      if (chewTimer > (ITEM_DRINK[useType] ? 0.36 : 0.22)) {
        chewTimer = 0;
        stepEnv = ITEM_DRINK[useType] ? 0.18 : 0.3;
      }
    }
  }

  // ---- the nerdolas
  playerExpo = exposure();
  updateFlow();
  if (survived > graceTime) for (Enemy e : enemies) updateAI(e, dt);

  nearE = null;
  nearD = 1e9;
  threatD = 1e9;
  anyChase = false;
  for (Enemy e : enemies) {
    float d = dist(player.x, player.y, e.pos.x, e.pos.y);
    if (d < KILL_DIST && now >= e.stunUntil) {
      die(e);
      return;
    }
    if (d < nearD) {
      nearD = d;
      nearE = e;
    }
    float td = threatDist(e, d);
    if (td < threatD) threatD = td;
    if (e.ai == CHASE) anyChase = true;
    if (now < e.stunUntil && random(1) < dt * 6) staticBurst = max(staticBurst, 0.08);
  }

  updateCans(dt);
  updateSecrets(dt);

  // ---- pick up drops
  for (int k = drops.size() - 1; k >= 0; k--) {
    Drop dr = drops.get(k);
    if (dist(player.x, player.y, dr.x, dr.y) < 110 && inv[dr.type] < MAX_STACK) {
      inv[dr.type]++;
      collectedType[dr.type]++;
      itemSeen[dr.type] = true;
      drops.remove(k);
      stepEnv = 0.3;
      showMsg("+ " + ITEM_NAMES[dr.type].toUpperCase() + "   [" + ITEM_KEYS[dr.type] + "]");
      spawnDrop();
      itemsCollected++;
      pickupTimes.add(now);
      while (pickupTimes.size() > 0 && now - pickupTimes.get(0) > 45000) pickupTimes.remove(0);
      if (pickupTimes.size() >= 6) unlock(5);
      if (itemsCollected >= 25) unlock(6);
      if (collectedType[TASER] >= 3 && collectedType[COXINHA] + collectedType[SALADA] + collectedType[LAGRIMAS] + collectedType[CESTA] == 0) unlock(18);
      if (inv[COXINHA] == MAX_STACK && inv[SALADA] == MAX_STACK && inv[LAGRIMAS] == MAX_STACK && inv[CESTA] == MAX_STACK) unlock(22);
    }
  }

  dropTimer += dt;
  if (dropTimer > DROP_ROTATE) {
    dropTimer = 0;
    ArrayList<Integer> farDrops = new ArrayList<Integer>();
    for (int k = 0; k < drops.size(); k++)
      if (dist(player.x, player.y, drops.get(k).x, drops.get(k).y) > CELL * 4) farDrops.add(k);
    if (!farDrops.isEmpty()) {
      drops.remove((int) farDrops.get((int) random(farDrops.size())));
      spawnDrop();
    }
  }

  for (Decal dc : decals) {
    if (dc.msg >= 0 && dist(player.x, player.y, dc.cx, dc.cy) < CELL * 1.3) {
      readMsg[dc.msg] = true;
      msgSeen[dc.msg] = true;
    }
  }

  if (gameMode == FUGA) {
    updateFuga(dt);
    if (state != PLAYING) return;
  }

  checkAchievements(nearD, nearE);

  float dg = danger(threatD);
  if (now < flickerUntil) {
    flicker = random(1) < 0.5 ? random(0.05, 0.4) : 1;
  } else {
    flicker = 1;
    if (random(1) < (3 * dg + 2 * chaseLvl) * dt) flickerUntil = now + random(80, 400);
  }
  spotFlash = max(0, spotFlash - dt * 2.5);

  float strafe = (kRight ? 1 : 0) - (kLeft ? 1 : 0);
  roll = lerp(roll, strafe * 0.03, 1 - exp(-dt * 7));
  float targetFov = radians(sprinting ? 82 : 72) - dg * radians(6);
  fov = lerp(fov, targetFov, 1 - exp(-dt * 5));

  updateLampGrid();

  float seen = localLight * 0.85 + (flashlightOn ? 0.18 * flicker : 0);
  float targetExp = constrain(sqrt(0.9 / max(0.15, seen)), 0.8, 1.6);
  exposureAdapt = lerp(exposureAdapt, targetExp, 1 - exp(-dt * 1.2));
  camGain = constrain(map(exposureAdapt, 0.8, 1.6, 0, 1), 0, 1);

  updateVoices();
  updateSynth(dt, dg);
}

boolean hitsWall(float x, float y) { return hitsWall(x, y, PLAYER_R); }

boolean hitsWall(float x, float y, float r) {
  for (int i = cellOf(x - r); i <= cellOf(x + r); i++) {
    for (int j = cellOf(y - r); j <= cellOf(y + r); j++) {
      if (!isWall(i, j)) continue;
      float cx = constrain(x, i * CELL, (i + 1) * CELL);
      float cy = constrain(y, j * CELL, (j + 1) * CELL);
      if (sq(x - cx) + sq(y - cy) < r * r) return true;
    }
  }
  return false;
}

// hips to eyes: the radius of the arc the head swings on when leaning
float leanArm() { return EYE_H * (1 - PEEK_PIVOT); }   // same reach crouched: the shoulders lean just as far

// how far the head can lean sideways (side -1 = left, 1 = right) before touching a wall
float leanRoom(int side) {
  float rx = -sin(yaw) * side, ry = cos(yaw) * side;
  float room = 0;
  float most = leanArm() * sin(PEEK_ANGLE);
  for (float s = 5; s <= most; s += 5) {
    if (hitsWall(player.x + rx * s, player.y + ry * s, PEEK_HEAD_R)) break;
    room = s;
  }
  return room;
}

// how far you can see straight ahead from (x, y) before a wall
float viewLen(float x, float y) {
  float fx = cos(yaw), fy = sin(yaw);
  for (float s = 20; s < PEEK_VIEW_GAIN * 4; s += 20) {
    if (isWall(cellOf(x + fx * s), cellOf(y + fy * s))) return s;
  }
  return PEEK_VIEW_GAIN * 4;
}

// a corner to lean around: a wall close in front of you whose edge is on that side,
// so leaning out opens the view. Returns where the eye goes, relative to the body, or null
PVector findCorner(int side) {
  float room = leanRoom(side);
  if (room < PEEK_MIN) return null;
  float near = viewLen(player.x, player.y);
  if (near > PEEK_WALL) return null;
  float ox = -sin(yaw) * side * room, oy = cos(yaw) * side * room;
  // check a few spots along the lean, not just the tip, so a thin gap counts too
  for (float t = 0.5; t <= 1.001; t += 0.25) {
    if (viewLen(player.x + ox * t, player.y + oy * t) >= near + PEEK_VIEW_GAIN) return new PVector(ox, oy);
  }
  return null;
}

boolean startPeek(int side) {
  PVector c = side < 0 ? peekL : peekR;
  if (c == null) return false;
  peekSide = peekDir = side;
  peekOff.set(c);
  return true;
}

// maze distance from the player to this enemy (999 if unknown)
int enemyPath(Enemy e) {
  int ei = cellOf(e.pos.x), ej = cellOf(e.pos.y);
  return (!isWall(ei, ej) && flow[ei][ej] >= 0) ? flow[ei][ej] : 999;
}

// Isa gives no warning until she's within 3 rooms
boolean hiddenThreat(Enemy e) {
  return e.ch == T_ISA && enemyPath(e) > 3;
}

float threatDist(Enemy e, float d) {
  return hiddenThreat(e) ? 1e9 : d;
}

// a random open cell 1..maxRooms (walking distance) from you — "somewhere around here", never your exact spot
int[] roughArea(int maxRooms) {
  ArrayList<int[]> cand = new ArrayList<int[]>();
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++)
    if (!solid[i][j] && flow[i][j] >= 1 && flow[i][j] <= maxRooms) cand.add(new int[]{i, j});
  if (cand.isEmpty()) return new int[]{cellOf(player.x), cellOf(player.y)};
  return cand.get((int) random(cand.size()));
}

// =====================================================================
// NEXTBOT AI (per nerdola, with traits)
float enemyBaseSpeed() {
  float t = max(0, survived - graceTime);
  if (gameMode == FUGA) return min(ENEMY_MAX + 40, ENEMY_START + certsTaken * CERT_SPEEDUP + t * ENEMY_RAMP * 0.4);
  return min(ENEMY_MAX, ENEMY_START + t * ENEMY_RAMP);
}

void updateAI(Enemy e, float dt) {
  int now = millis();
  int c = e.ch;
  if (now < e.stunUntil) {
    e.sees = false;
    return;
  }
  if (c == T_LUCA) {
    if (playerSees(e)) e.unseenFor = 0;
    else e.unseenFor += dt;
    if (now >= e.nextTeleport && e.unseenFor > 0.8) teleport(e);   // never while you're watching
  }

  float d = dist(player.x, player.y, e.pos.x, e.pos.y);
  int path = enemyPath(e);
  boolean ghost = now < ghostUntil;
  boolean confused = now < e.confusedUntil;

  // ---- sight: a cone ahead of it, a clear line, and range by how lit you are;
  // invisible = never seen; crouching shrinks it
  float sight = (flashlightOn ? SIGHT_FLASH : SIGHT_CELLS * lerp(SIGHT_DARK, 1, playerExpo)) * CELL * SIGHT_MUL[c];
  if (crouching) sight *= moving ? CROUCH_SIGHT : CROUCH_STILL_SIGHT;
  boolean inCone = abs(angleDiff(e.face, atan2(player.y - e.pos.y, player.x - e.pos.x))) < VIEW_HALF;
  e.sees = !ghost && !confused && d < sight && inCone && lineOfSight(e.pos.x, e.pos.y, player.x, player.y);

  // ---- hearing: only while moving; crouch-walking = same room (Gustavo: one room)
  float hearRange;
  if (crouching) hearRange = c == T_GUSTAVO ? 1 : 0;
  else hearRange = (sprinting ? HEAR_SPRINT : HEAR_WALK) * HEAR_MUL[c];
  if (ghost) hearRange *= GHOST_HEAR;
  boolean hears = moving && !confused && path <= hearRange;

  // ---- proximity bubble
  float touch = ghost ? GHOST_TOUCH : (crouching ? CROUCH_TOUCH : TOUCH_CELLS);
  boolean bumped = !confused && d < CELL * touch;

  // ---- peeking around a corner: only one coming up behind you notices you
  if (peekSide != 0 && (e.pos.x - player.x) * cos(yaw) + (e.pos.y - player.y) * sin(yaw) >= 0) {
    e.sees = hears = bumped = false;
  }

  boolean detected = e.sees || hears || bumped;

  if (detected) {
    if (e.ai != CHASE) {
      triggerSting(e);
      staticBurst = max(staticBurst, 0.3);
      e.lockUntil = now + LOCK_MS;
      e.lungeUntil = e.lockUntil + LUNGE_MS;
      e.chaseTime = 0;
      everSpotted = true;
      chasesStarted++;
    }
    e.ai = CHASE;
    e.lostTimer = 0;
    e.senseTimer = 0;
    e.lastSeen.set(player.x, player.y);
    e.lastVX = pvx;
    e.lastVY = pvy;
  } else if (e.ai == CHASE) {
    if (e.lostTimer == 0 && c == T_VITOR) {           // the instant he loses you, he guesses where you were heading
      int[] pc = predictFrom(e.lastSeen.x, e.lastSeen.y, e.lastVX, e.lastVY);
      if (pc != null) e.lastSeen.set((pc[0] + 0.5) * CELL, (pc[1] + 0.5) * CELL);
    }
    e.lostTimer += dt;
    if (e.lostTimer >= MEMORY * MEM_MUL[c]) {
      e.ai = SEARCH;
      e.searchTimer = 0;
      chasesEscaped++;
      if (chasesEscaped >= 8) unlock(9);
      if (ghost) unlock(21);
    }
  } else if (!confused && !ghost) {
    e.senseTimer += dt;
    if (e.senseTimer > SENSE_TIME * SENSE_MUL[c]) {
      e.senseTimer = 0;
      int[] g = roughArea(3);
      e.lastSeen.set((g[0] + 0.5) * CELL, (g[1] + 0.5) * CELL);
      e.ai = SEARCH;
      e.searchTimer = 0;
    }
  }

  float speed = enemyBaseSpeed() * SPEED_MUL[c] * (enemies.size() > 1 ? MULTI_SPEED : 1);
  PVector target = null;

  if (e.ai == CHASE) {
    e.chaseTime += dt;
    if (e.chaseTime >= 30) unlock(23);
    if (now < e.lockUntil) speed = 0;
    else if (now < e.lungeUntil) speed *= LUNGE_MULT * LUNGE_MUL[c];
    if (e.chaseTime > FRENZY_TIME) speed *= FRENZY_MULT;
    boolean live = detected && !ghost;
    if (live && c == T_VITOR && d > CELL * 2) {
      int[] pc = predictCell();
      if (pc != null) {
        setGoal(e, pc[0], pc[1]);
        target = stepOn(e, e.goalFlow, goalCenter(e));
      }
    }
    if (target == null) {
      if (live) {
        target = stepOn(e, flow, new PVector(player.x, player.y));
      } else {                                        // run to the last genuine fix
        setGoal(e, cellOf(e.lastSeen.x), cellOf(e.lastSeen.y));
        target = stepOn(e, e.goalFlow, goalCenter(e));
        if (!detected && atGoal(e)) e.lostTimer = MEMORY * MEM_MUL[c];
      }
    }
  } else if (e.ai == SEARCH) {
    e.chaseTime = 0;
    setGoal(e, cellOf(e.lastSeen.x), cellOf(e.lastSeen.y));
    speed *= 0.8;
    if (atGoal(e)) {
      speed = 0;
      e.searchTimer += dt;
      if (e.searchTimer > SEARCH_WAIT * SEARCH_MUL[c]) {
        e.ai = WANDER;
        pickWander(e);
      }
    }
    target = stepOn(e, e.goalFlow, goalCenter(e));
  } else {
    e.chaseTime = 0;
    if (e.goalI < 0 || atGoal(e)) pickWander(e);
    speed *= 0.55;
    target = stepOn(e, e.goalFlow, goalCenter(e));
  }

  PVector dir = PVector.sub(target, e.pos);
  float m = dir.mag();
  boolean mv = m > 0 && speed > 0;
  if (mv) e.pos.add(dir.mult(min(speed * dt, m) / m));

  // ---- where it looks: at you while it sees you, along its way while walking,
  // and scanning left and right when it stands still
  float want;
  if (e.sees) {
    want = atan2(player.y - e.pos.y, player.x - e.pos.x);
  } else if (mv) {
    want = atan2(dir.y, dir.x);
  } else {
    if (e.wasMoving) {
      e.scanBase = e.face;
      e.scanT = 0;
    }
    e.scanT += dt;
    want = e.scanBase + sin(e.scanT * 1.3) * 1.6;
  }
  e.wasMoving = mv;
  float turn = angleDiff(e.face, want);
  e.face += constrain(turn, -TURN_RATE * dt, TURN_RATE * dt);
}

// shortest signed angle from a to b, in [-PI, PI)
float angleDiff(float a, float b) {
  float d = (b - a) % TWO_PI;
  if (d >= PI) d -= TWO_PI;
  if (d < -PI) d += TWO_PI;
  return d;
}

// how lit you are by the fixed lamps around you (0 = pitch dark, 1 = fully lit). Flicker and the
// nerdolas killing the lights don't count: the dark corners stay dark, so you can learn where to hide
float exposure() {
  float acc = 0;
  int pi = cellOf(player.x), pj = cellOf(player.y);
  for (int i = pi - 1; i <= pi + 1; i++) for (int j = pj - 1; j <= pj + 1; j++) {
    if (isWall(i, j) || lampType[i][j] == 2) continue;
    float lx = (i + 0.5) * CELL, ly = (j + 0.5) * CELL;
    if (!lineOfSight(player.x, player.y, lx, ly)) continue;   // walls block the light
    float dd = dist(player.x, player.y, lx, ly);
    acc += (lampType[i][j] == 1 ? 0.7 : 1) * constrain(1 - dd / (CELL * LAMP_REACH), 0, 1);
  }
  return constrain(acc * 0.7, 0, 1);
}

// =====================================================================
// MONSTER: while PILHADO you see the nerdolas through the walls
// Their faces are drawn again with the depth test flipped (GREATER): only the parts hidden
// behind a wall show up, as a cold ghost. In plain sight you just see them as usual.
void drawXray() {
  int now = millis();
  if (now >= pilhadoUntil || enemies.isEmpty()) return;
  float fade = constrain((pilhadoUntil - now) / 1500.0, 0, 1)
    * constrain((now - (pilhadoUntil - BUFF_MS[MONSTER])) / 400.0, 0, 1);
  float pulse = 0.85 + 0.15 * sin(now * 0.008);
  noLights();
  noStroke();
  textureWrap(CLAMP);
  flush();
  PGL pgl = beginPGL();
  pgl.depthFunc(PGL.GREATER);
  pgl.depthMask(false);
  for (Enemy e : enemies) {
    float d = dist(player.x, player.y, e.pos.x, e.pos.y);
    float far = map(constrain(d, CELL * 8, CELL * 20), CELL * 8, CELL * 20, 1, 0.35);
    tint(150, 205, 255, 255 * XRAY_ALPHA * fade * pulse * far);
    float sz = 300, base = 40;
    pushMatrix();
    translate(e.pos.x, e.pos.y, 0);
    rotateZ(atan2(player.y - e.pos.y, player.x - e.pos.x));
    beginShape(QUADS);
    texture(faces[e.ch]);
    vertex(0,  sz / 2, base + sz, 0, 0);
    vertex(0, -sz / 2, base + sz, 1, 0);
    vertex(0, -sz / 2, base, 1, 1);
    vertex(0,  sz / 2, base, 0, 1);
    endShape();
    popMatrix();
  }
  flush();
  pgl.depthFunc(PGL.LEQUAL);
  pgl.depthMask(true);
  endPGL();
  noTint();
}

// =====================================================================
// THE BLESSING OF CABRAL: dark dead ends that open under the flashlight, and the Pizza do Papponi
// one pizza per phase: POLIWEEK days 0-5, VS. 6, RECUPERAÇÃO, then ENDLESS
int phase() {
  return runDay >= 0 ? runDay : PHASES - 1;
}

float pizzaMul() {
  int n = 0;
  for (boolean b : pizzaGot) if (b) n++;
  return 1 + PIZZA_BONUS * n;
}

// dark dead ends whose far wall opens: into a hidden nook if it's walled in on every other side,
// otherwise into a secret shortcut to the corridor behind it (nooks are picked first)
void placeSecrets() {
  secrets.clear();
  ArrayList<int[]> cand = new ArrayList<int[]>();
  for (int i = 1; i < GRID - 1; i++) for (int j = 1; j < GRID - 1; j++) {
    if (isWall(i, j) || flow[i][j] < 4) continue;
    int open = 0, oi = 0, oj = 0;
    for (int[] d : DIRS) {
      if (isWall(i + d[0], j + d[1])) continue;
      open++;
      oi = d[0];
      oj = d[1];
    }
    if (open != 1) continue;
    int wi = i - oi, wj = j - oj;              // the wall facing you as you walk in
    if (wi < 1 || wj < 1 || wi > GRID - 2 || wj > GRID - 2) continue;
    int around = 0;
    for (int[] d : DIRS) {
      int ni = wi + d[0], nj = wj + d[1];
      if ((ni != i || nj != j) && !isWall(ni, nj)) around++;
    }
    cand.add(new int[]{i, j, wi, wj, around + (flow[i][j] > SECRET_NEAR ? 10 : 0)});
  }
  java.util.Collections.shuffle(cand);
  java.util.Collections.sort(cand, new java.util.Comparator<int[]>() {
    public int compare(int[] a, int[] b) { return a[4] - b[4]; }
  });
  boolean pizzaLeft = !pizzaGot[phase()];
  for (int[] c : cand) {
    if (secrets.size() >= SECRETS) break;
    boolean nextToOther = false;                // two nooks side by side would open into each other
    for (Secret o : secrets) if (abs(o.wi - c[2]) + abs(o.wj - c[3]) <= 1) nextToOther = true;
    if (nextToOther) continue;
    Secret s = new Secret();
    s.di = c[0];
    s.dj = c[1];
    s.wi = c[2];
    s.wj = c[3];
    s.pizza = pizzaLeft && secrets.isEmpty();
    lampType[s.di][s.dj] = 2;                   // always a dark dead end
    secrets.add(s);
  }
}

// paint Cabral's sun on each secret wall, at eye height
void markSecrets() {
  for (Secret s : secrets) {
    Decal dc = new Decal();
    dc.nx = s.di - s.wi;
    dc.ny = s.dj - s.wj;
    dc.cx = (s.di + 0.5) * CELL - dc.nx * (CELL * 0.5 - 2);
    dc.cy = (s.dj + 0.5) * CELL - dc.ny * (CELL * 0.5 - 2);
    dc.z = 185;
    dc.w = dc.h = 120;
    dc.msg = -1;
    dc.tex = cabralMark;
    decals.add(dc);
    s.mark = dc;
  }
}

// a sun with a C in it, in the same dripping red paint as the graffiti
PImage makeCabralMark() {
  java.util.Random rng = new java.util.Random(77);
  PGraphics g = createGraphics(256, 256);
  g.beginDraw();
  g.clear();
  g.translate(128, 122);
  g.noFill();
  for (int pass = 0; pass < 2; pass++) {
    g.stroke(pass == 0 ? color(120, 8, 6, 120) : color(150, 12, 10, 235));
    g.strokeWeight(pass == 0 ? 16 : 9);
    g.ellipse(0, 0, 120, 120);
    for (int k = 0; k < 12; k++) {
      float a = k * TWO_PI / 12 + 0.1, r0 = 76, r1 = k % 2 == 0 ? 112 : 98;
      g.line(cos(a) * r0, sin(a) * r0, cos(a) * r1, sin(a) * r1);
    }
  }
  g.noStroke();
  g.fill(150, 12, 10, 235);
  g.textFont(fontGraffiti);
  g.textAlign(CENTER, CENTER);
  g.textSize(84);
  g.text("C", 0, 6);
  for (int k = 0; k < 7; k++) {                // drips
    float x = (rng.nextFloat() - 0.5) * 110, y = 20 + rng.nextFloat() * 40;
    float len = 12 + rng.nextFloat() * 50;
    g.stroke(140, 12, 10, 220);
    g.strokeWeight(3 + rng.nextFloat() * 3);
    g.line(x, y, x, y + len);
  }
  g.endDraw();
  return g.get();
}

boolean secretWall(int i, int j) {
  for (Secret s : secrets) if (!s.open && s.wi == i && s.wj == j) return true;
  return false;
}

// a wall face things can hang on (not a secret one: it's going to open)
boolean wallFace(int i, int j) {
  return isWall(i, j) && !secretWall(i, j);
}

void updateSecrets(float dt) {
  for (Secret s : secrets) {
    float dcx = (s.di + 0.5) * CELL, dcy = (s.dj + 0.5) * CELL;
    if (!s.open) {
      // the far wall of the dead end, in your flashlight's beam, from close by
      float wx = dcx + (s.wi - s.di) * CELL * 0.5, wy = dcy + (s.wj - s.dj) * CELL * 0.5;
      float d = dist(player.x, player.y, wx, wy);
      float aim = abs(angleDiff(yaw, atan2(wy - player.y, wx - player.x)));
      boolean lit = flashlightOn && d < CELL * 2.2 && aim < radians(20) && abs(pitch) < 0.7
        && lineOfSight(player.x, player.y, dcx, dcy);
      s.light = lit ? s.light + dt : max(0, s.light - dt * 2);
      if (lit) staticBurst = max(staticBurst, 0.15 * s.light / REVEAL_TIME);
      if (s.light >= REVEAL_TIME) openSecret(s);
    } else if (s.pizza && !s.eaten && dist(player.x, player.y, (s.wi + 0.5) * CELL, (s.wj + 0.5) * CELL) < 130) {
      eatPizza(s);
    }
  }
}

void openSecret(Secret s) {
  s.open = true;
  decals.remove(s.mark);
  solid[s.wi][s.wj] = false;
  lampType[s.wi][s.wj] = 0;                     // the nook is lit: the blessing
  level = buildLevel();
  flowI = -1;
  updateFlow();
  staticBurst = max(staticBurst, 0.5);
  achT = 0;                                     // the little chime
  if (s.pizza) {
    showMsg("A BÊNÇÃO DO CABRAL  —  UMA PASSAGEM SE ABRIU");
  } else {
    showMsg("UMA PASSAGEM SECRETA...");
    drops.add(new Drop((s.wi + 0.5) * CELL, (s.wj + 0.5) * CELL, nextDropType()));
  }
}

void eatPizza(Secret s) {
  s.eaten = true;
  pizzaGot[phase()] = true;
  saveProgress();
  stamina = staminaMax();
  exhausted = false;
  achT = 0;
  stepEnv = 0.3;
  showMsg("PIZZA DO PAPPONI  —  FÔLEGO MÁXIMO +" + round(PIZZA_BONUS * 100) + "% PARA SEMPRE");
}

void drawPizzas() {
  float t = millis() / 1000.0;
  noStroke();
  for (Secret s : secrets) {
    if (!s.open || !s.pizza || s.eaten) continue;
    float x = (s.wi + 0.5) * CELL, y = (s.wj + 0.5) * CELL;
    float dd = dist(player.x, player.y, x, y);
    if (dd > CELL * 6) continue;
    itemLights(x, y, lerp(1, exp(-pow(dd / FOG_DIST, 1.5)), 0.5));
    emissive(45, 28, 8);                        // a warm, blessed glow
    pushMatrix();
    translate(x, y, 125 + sin(t * 2.2) * 10);
    rotateZ(t * 1.1);
    rotateX(-HALF_PI + 1.15);                   // nearly upright, so the toppings face you as it spins
    scale(1.1);
    shape(pizzaModel);
    popMatrix();
    emissive(0);
    flush();
  }
  noLights();
  lightFalloff(1, 0, 0);
  specular(0);
}

// a textured OBJ as one triangle mesh (the Blender export flips handedness: mirror x back)
PShape loadModel(String file, String texFile) {
  ArrayList<PVector> vs = new ArrayList<PVector>(), vt = new ArrayList<PVector>(), vn = new ArrayList<PVector>();
  PShape sh = createShape();
  sh.beginShape(TRIANGLES);
  sh.noStroke();
  sh.texture(loadImage(texFile));
  sh.fill(255);
  sh.specular(40);
  sh.shininess(12);
  for (String ln : loadStrings(file)) {
    String[] p = splitTokens(ln);
    if (p.length == 0) continue;
    if (p[0].equals("v")) vs.add(new PVector(-float(p[1]), float(p[2]), float(p[3])));
    else if (p[0].equals("vt")) vt.add(new PVector(float(p[1]), 1 - float(p[2])));
    else if (p[0].equals("vn")) vn.add(new PVector(-float(p[1]), float(p[2]), float(p[3])));
    else if (p[0].equals("f")) {
      for (int a = 3; a >= 1; a--) {
        String[] ix = split(p[a], '/');
        PVector v = vs.get(int(ix[0]) - 1);
        if (ix.length > 2 && ix[2].length() > 0) {
          PVector nn = vn.get(int(ix[2]) - 1);
          sh.normal(nn.x, nn.y, nn.z);
        }
        PVector tc = (ix.length > 1 && ix[1].length() > 0) ? vt.get(int(ix[1]) - 1) : new PVector();
        sh.vertex(v.x, v.y, v.z, tc.x, tc.y);
      }
    }
  }
  sh.endShape();
  return sh;
}

// =====================================================================
// THE EMPTY CAN: thrown with physics, clanks, and the nerdolas come to check
void throwCan() {
  int now = millis();
  if (inv[LATA] <= 0 || useType >= 0 || now - lastThrow < 400) return;
  inv[LATA]--;
  lastThrow = now;
  Can c = new Can();
  float cp = cos(pitch);
  c.x = camX + cos(yaw) * 30;
  c.y = camY + sin(yaw) * 30;
  c.z = camZ - 30;
  if (isWall(cellOf(c.x), cellOf(c.y))) {    // hugging a wall: start from the body instead
    c.x = player.x;
    c.y = player.y;
  }
  c.vx = cos(yaw) * cp * CAN_SPEED + pvx * 0.5;
  c.vy = sin(yaw) * cp * CAN_SPEED + pvy * 0.5;
  c.vz = sin(pitch) * CAN_SPEED + CAN_LOFT;
  c.heading = yaw + HALF_PI;                  // tumbles end over end along the throw
  c.tumbleV = random(9, 14) * (random(1) < 0.5 ? -1 : 1);
  c.lastClank = c.lastAlert = -99999;
  cans.add(c);
  if (cans.size() > MAX_CANS) cans.remove(0);
}

void updateCans(float dt) {
  for (Can c : cans) {
    if (c.rest) continue;
    float fastest = max(abs(c.vx), abs(c.vy), abs(c.vz));
    int n = max(1, ceil(fastest * dt / 8));     // small substeps: never skips through a wall
    for (int k = 0; k < n && !c.rest; k++) stepCan(c, dt / n);
  }
}

void stepCan(Can c, float h) {
  float r = CAN_FLOOR + 2;
  c.vz -= GRAVITY * h;
  float nx = c.x + c.vx * h;
  if (isWall(cellOf(nx + (c.vx > 0 ? r : -r)), cellOf(c.y))) {
    canHit(c, abs(c.vx));
    c.vx *= -0.45;
    c.vy *= 0.8;
    c.tumbleV = -c.tumbleV * 0.7 + random(-4, 4);
  } else {
    c.x = nx;
  }
  float ny = c.y + c.vy * h;
  if (isWall(cellOf(c.x), cellOf(ny + (c.vy > 0 ? r : -r)))) {
    canHit(c, abs(c.vy));
    c.vy *= -0.45;
    c.vx *= 0.8;
    c.tumbleV = -c.tumbleV * 0.7 + random(-4, 4);
  } else {
    c.y = ny;
  }
  c.z += c.vz * h;
  if (c.z > WALL_H - r) {
    c.z = WALL_H - r;
    if (c.vz > 0) {
      canHit(c, c.vz);
      c.vz = -c.vz * 0.3;
    }
  }
  if (c.z <= CAN_FLOOR) {
    c.z = CAN_FLOOR;
    if (c.vz < -90) {                         // bounce
      canHit(c, -c.vz);
      c.vz = -c.vz * 0.32;
      c.vx *= 0.7;
      c.vy *= 0.7;
      c.tumbleV *= 0.6;
    } else {                                  // sliding on the carpet, settling flat on its top or bottom
      c.vz = 0;
      float f = exp(-h * 4);
      c.vx *= f;
      c.vy *= f;
      float lie = round(c.tumble / PI) * PI;
      c.tumble = lerp(c.tumble, lie, 1 - exp(-h * 12));
      c.tumbleV = 0;
      if (sqrt(c.vx * c.vx + c.vy * c.vy) < 12) c.rest = true;
      return;
    }
  }
  c.tumble += c.tumbleV * h;
}

// an impact of speed v: you hear it, and a loud one carries to the nerdolas
void canHit(Can c, float v) {
  int now = millis();
  if (v < 70 || now - c.lastClank < 90) return;
  c.lastClank = now;
  float loud = constrain(v / 900, 0, 1);
  float d = dist(player.x, player.y, c.x, c.y);
  AudioSample snd = clanks[(int) random(clanks.length)];
  float gain = -24 + 24 * loud - d / CELL * 2.5;
  setVoice(snd, max(gain, -60) + volDb(V_FX), sin(atan2(c.y - player.y, c.x - player.x) - yaw));
  snd.trigger();
  if (loud > 0.25 && now - c.lastAlert > 600) {
    c.lastAlert = now;
    canNoise(c.x, c.y, loud);
  }
}

// nerdolas within earshot (through the maze) drop what they're doing and go check the spot
void canNoise(float x, float y, float loud) {
  int[][] f = bfs(cellOf(x), cellOf(y));
  int now = millis();
  for (Enemy e : enemies) {
    if (now < e.stunUntil || (e.ai == CHASE && e.sees)) continue;
    int ei = cellOf(e.pos.x), ej = cellOf(e.pos.y);
    if (isWall(ei, ej) || f[ei][ej] < 0) continue;
    if (f[ei][ej] > CAN_HEAR * (0.5 + 0.5 * loud) * HEAR_MUL[e.ch]) continue;
    e.ai = SEARCH;
    e.lastSeen.set(x, y);
    e.searchTimer = e.lostTimer = e.senseTimer = 0;
    e.goalI = -1;
  }
}

void drawCans3D() {
  if (cans.isEmpty()) return;
  noStroke();
  for (Can c : cans) {
    float dd = dist(player.x, player.y, c.x, c.y);
    if (dd > CELL * 6) continue;
    itemLights(c.x, c.y, lerp(1, exp(-pow(dd / FOG_DIST, 1.5)), 0.5) * 0.7);   // white metal: keep the flashlight from blowing it out
    pushMatrix();
    translate(c.x, c.y, c.z);
    rotateZ(c.heading);
    rotateX(-HALF_PI + c.tumble);
    scale(CAN_SCALE);
    translate(0, 27, 0);                      // the model stands on its base: spin around its middle
    drawItem(lataModel);
    popMatrix();
    flush();
  }
  noLights();
  lightFalloff(1, 0, 0);
  specular(0);
  emissive(0);
}

float modelCan() {
  shape(canModel);
  return 100;
}

float modelLata() {
  drawItem(lataModel);
  return 54;
}

// the can as one triangle mesh per material (Processing's own OBJ loader makes a shape per triangle).
// The export flips handedness, so x is mirrored back (and the winding with it)
PShape loadCan(String file) {
  ArrayList<PVector> vs = new ArrayList<PVector>(), vt = new ArrayList<PVector>(), vn = new ArrayList<PVector>();
  PShape grp = createShape(GROUP);
  PShape cur = null;
  PImage label = loadImage("monster_label.jpg");
  for (String ln : loadStrings(file)) {
    String[] p = splitTokens(ln);
    if (p.length == 0) continue;
    if (p[0].equals("v")) vs.add(new PVector(-float(p[1]), float(p[2]), float(p[3])));
    else if (p[0].equals("vt")) vt.add(new PVector(float(p[1]), 1 - float(p[2])));
    else if (p[0].equals("vn")) vn.add(new PVector(-float(p[1]), float(p[2]), float(p[3])));
    else if (p[0].equals("usemtl")) {
      if (cur != null) {
        cur.endShape();
        grp.addChild(cur);
      }
      cur = createShape();
      cur.beginShape(TRIANGLES);
      cur.noStroke();
      if (p[1].equals("label")) {
        cur.texture(label);
        cur.fill(255);
        cur.specular(60);
        cur.shininess(20);
      } else if (p[1].equals("Can_cover")) {
        cur.fill(198, 198, 204);
        cur.specular(170);
        cur.shininess(40);
      } else {
        cur.fill(184, 186, 192);
        cur.specular(190);
        cur.shininess(50);
      }
    } else if (p[0].equals("f") && cur != null) {
      for (int a = 3; a >= 1; a--) {
        String[] ix = split(p[a], '/');
        PVector v = vs.get(int(ix[0]) - 1);
        if (ix.length > 2 && ix[2].length() > 0) {
          PVector nn = vn.get(int(ix[2]) - 1);
          cur.normal(nn.x, nn.y, nn.z);
        }
        if (ix.length > 1 && ix[1].length() > 0) {
          PVector t = vt.get(int(ix[1]) - 1);
          cur.vertex(v.x, v.y, v.z, t.x, t.y);
        } else {
          cur.vertex(v.x, v.y, v.z);
        }
      }
    }
  }
  if (cur != null) {
    cur.endShape();
    grp.addChild(cur);
  }
  return grp;
}

// metallic clanks, synthesized: a few inharmonic partials ringing out + the tick of the hit
AudioSample[] makeClanks() {
  javax.sound.sampled.AudioFormat fmt = new javax.sound.sampled.AudioFormat(44100, 16, 1, true, false);
  float[][] freqs = {{1180, 2710, 4150, 5890, 520}, {960, 2330, 3870, 6120, 470}, {1420, 3050, 4630, 7020, 610}};
  float[] amps  = {1, 0.7, 0.5, 0.35, 0.8};
  float[] decay = {9, 14, 20, 28, 30};
  AudioSample[] res = new AudioSample[freqs.length];
  for (int v = 0; v < freqs.length; v++) {
    int n = (int) (44100 * 0.5);
    float[] buf = new float[n];
    float peak = 0;
    for (int i = 0; i < n; i++) {
      float t = i / 44100.0;
      float x = 0;
      for (int k = 0; k < amps.length; k++) x += amps[k] * sin(TWO_PI * freqs[v][k] * t + k) * exp(-t * decay[k]);
      if (i < 400) x += random(-1, 1) * (1 - i / 400.0) * 1.2;
      buf[i] = x;
      peak = max(peak, abs(x));
    }
    for (int i = 0; i < n; i++) buf[i] *= 0.7 / peak;
    res[v] = minim.createSample(buf, fmt, 512);
  }
  return res;
}

// the cell someone moving from (x,y) with velocity (vx,vy) will be in ~1.2 s later, stopping at walls
int[] predictFrom(float x, float y, float vx, float vy) {
  float sp = sqrt(vx * vx + vy * vy);
  if (sp < 60) return null;
  float ux = vx / sp, uy = vy / sp;
  float reach = min(sp * 1.2, CELL * 3);
  int bi = -1, bj = -1;
  for (float s = CELL * 0.5; s <= reach; s += CELL * 0.25) {
    int i = cellOf(x + ux * s), j = cellOf(y + uy * s);
    if (isWall(i, j)) break;
    bi = i;
    bj = j;
  }
  if (bi < 0 || (bi == cellOf(x) && bj == cellOf(y))) return null;
  return new int[]{bi, bj};
}

int[] predictCell() { return predictFrom(player.x, player.y, pvx, pvy); }

// is this nerdola on your screen, close enough to make out, with nothing in between?
boolean playerSees(Enemy e) {
  float d = dist(player.x, player.y, e.pos.x, e.pos.y);
  if (d > CELL * 10 || !e.inFront) return false;
  float margin = width * 0.25;
  if (e.sx < -margin || e.sx > width + margin || e.sy < -height * 0.5 || e.sy > height * 1.5) return false;
  return lineOfSight(player.x, player.y, e.pos.x, e.pos.y);
}

// Luca: vanish and reappear 5-8 rooms away, out of your sight
void teleport(Enemy e) {
  e.nextTeleport = millis() + (int) random(14000, 24000);
  ArrayList<int[]> cand = new ArrayList<int[]>();
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    if (solid[i][j] || flow[i][j] < 5 || flow[i][j] > 8) continue;
    if (lineOfSight((i + 0.5) * CELL, (j + 0.5) * CELL, player.x, player.y)) continue;
    cand.add(new int[]{i, j});
  }
  if (cand.isEmpty()) return;
  int[] c = cand.get((int) random(cand.size()));
  e.pos.set((c[0] + 0.5) * CELL, (c[1] + 0.5) * CELL);
  if (millis() < ghostUntil) {
    e.ai = WANDER;
    pickWander(e);
  } else {
    int[] g = roughArea(3);
    e.ai = SEARCH;
    e.lastSeen.set((g[0] + 0.5) * CELL, (g[1] + 0.5) * CELL);
    e.searchTimer = 0;
  }
  e.lostTimer = 0;
  e.goalI = -1;
}

boolean lineOfSight(float x0, float y0, float x1, float y1) {
  int n = max(1, ceil(dist(x0, y0, x1, y1) / (CELL * 0.2)));
  for (int k = 1; k < n; k++) {
    float t = k / (float) n;
    if (isWall(cellOf(lerp(x0, x1, t)), cellOf(lerp(y0, y1, t)))) return false;
  }
  return true;
}

void setGoal(Enemy e, int gi, int gj) {
  if (gi == e.goalI && gj == e.goalJ) return;
  e.goalI = gi;
  e.goalJ = gj;
  e.goalFlow = bfs(gi, gj);
}

PVector goalCenter(Enemy e) {
  return new PVector((e.goalI + 0.5) * CELL, (e.goalJ + 0.5) * CELL);
}

boolean atGoal(Enemy e) {
  return e.goalI >= 0 && dist(e.pos.x, e.pos.y, (e.goalI + 0.5) * CELL, (e.goalJ + 0.5) * CELL) < 30;
}

void pickWander(Enemy e) {
  int pi = cellOf(player.x), pj = cellOf(player.y);
  int ei = cellOf(e.pos.x), ej = cellOf(e.pos.y);
  for (int tries = 0; tries < 40; tries++) {
    int gi, gj;
    if (random(1) < 0.6) {
      gi = pi + (int) random(-6, 7);
      gj = pj + (int) random(-6, 7);
    } else {
      int[] c = randomOpenCell();
      gi = c[0];
      gj = c[1];
    }
    if (isWall(gi, gj) || (gi == ei && gj == ej)) continue;
    e.goalI = -1;
    setGoal(e, gi, gj);
    if (!isWall(ei, ej) && e.goalFlow[ei][ej] > 0) return;
  }
}

void pickWanderFar(Enemy e) {
  int ei = cellOf(e.pos.x), ej = cellOf(e.pos.y);
  for (int tries = 0; tries < 60; tries++) {
    int[] c = randomOpenCell();
    if (flow[c[0]][c[1]] < 9) continue;
    e.goalI = -1;
    setGoal(e, c[0], c[1]);
    if (!isWall(ei, ej) && e.goalFlow[ei][ej] > 0) return;
  }
  pickWander(e);
}

// =====================================================================
// PATHFINDING
int[][] bfs(int si, int sj) {
  int[][] f = new int[GRID][GRID];
  for (int[] row : f) java.util.Arrays.fill(row, -1);
  if (isWall(si, sj)) return f;
  int[] qi = new int[GRID * GRID], qj = new int[GRID * GRID];
  int head = 0, tail = 0;
  f[si][sj] = 0;
  qi[tail] = si;
  qj[tail++] = sj;
  while (head < tail) {
    int i = qi[head], j = qj[head++];
    for (int[] d : DIRS) {
      int ni = i + d[0], nj = j + d[1];
      if (!isWall(ni, nj) && f[ni][nj] < 0) {
        f[ni][nj] = f[i][j] + 1;
        qi[tail] = ni;
        qj[tail++] = nj;
      }
    }
  }
  return f;
}

void updateFlow() {
  int pi = cellOf(player.x), pj = cellOf(player.y);
  if (pi == flowI && pj == flowJ) return;
  flowI = pi;
  flowJ = pj;
  flow = bfs(pi, pj);
}

PVector stepOn(Enemy e, int[][] f, PVector finalPt) {
  int ei = cellOf(e.pos.x), ej = cellOf(e.pos.y);
  if (f == null || isWall(ei, ej) || f[ei][ej] <= 0) return finalPt;
  int bi = ei, bj = ej;
  for (int[] d : DIRS) {
    int ni = ei + d[0], nj = ej + d[1];
    if (!isWall(ni, nj) && f[ni][nj] >= 0 && f[ni][nj] < f[bi][bj]) {
      bi = ni;
      bj = nj;
    }
  }
  return new PVector((bi + 0.5) * CELL, (bj + 0.5) * CELL);
}

float danger(float d) {
  return constrain(1 - d / (CELL * 6), 0, 1);
}

// =====================================================================
// LIGHTS
float lampPower(int i, int j) {
  int t = lampType[i][j];
  if (t == 2) return 0;
  float ms = millis();
  float p = 1;
  if (t == 1) {
    float n = noise(i * 13.7, j * 7.3, ms * 0.003);
    p = n > 0.38 ? 1 : (n > 0.32 ? 0.3 : 0.04);
  }
  float radius = CELL * (2.2 + 1.3 * chaseLvl);
  float cx = (i + 0.5) * CELL, cy = (j + 0.5) * CELL;
  float e = 0;
  for (Enemy en : enemies) {
    if (en.ch == T_ISA) continue;                      // Isa leaves the lights alone
    e = max(e, constrain(1 - dist(cx, cy, en.pos.x, en.pos.y) / radius, 0, 1));
  }
  if (e > 0 && noise(i * 3.1 + 40, j * 5.7, ms * 0.015) < e * 0.85) p *= 0.06;
  return p;
}

void updateLampGrid() {
  java.util.Arrays.fill(mapU, 0);
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    lampP[i][j] = solid[i][j] ? 0 : lampPower(i, j);
    int code = solid[i][j] ? 0 : 1 + round(lampP[i][j] * 15);
    int idx = j * GRID + i;
    mapU[idx / 4] += code * PACK[idx % 4];
  }
  humLevel = 0;
  float acc = 0;
  int pi = cellOf(player.x), pj = cellOf(player.y);
  for (int i = pi - 1; i <= pi + 1; i++) for (int j = pj - 1; j <= pj + 1; j++) {
    if (isWall(i, j)) continue;
    float dd = dist(player.x, player.y, (i + 0.5) * CELL, (j + 0.5) * CELL);
    humLevel = max(humLevel, lampP[i][j] * constrain(1 - dd / (CELL * 2), 0, 1));
    acc += lampP[i][j] * constrain(1 - dd / (CELL * 1.6), 0, 1);
  }
  localLight = constrain(acc * 0.7, 0, 1.2);
}

void updateVoices() {
  int now = millis();
  for (Enemy e : enemies) {
    float d = dist(player.x, player.y, e.pos.x, e.pos.y);
    int path = enemyPath(e);
    float heard = path < 999 ? max(d, path * CELL * 0.8) : d;
    float range = e.ch == T_GUSTAVO ? CELL * 20 : CELL * 14;
    float gain = map(constrain(heard, 0, range), 0, range, 3, -40);
    if (e.ch == T_GUSTAVO) gain += 6;
    if (e.ai != CHASE) gain -= 3;
    if (now < e.screamUntil) gain += 6;
    if (now < e.stunUntil) gain -= 10;
    if (hiddenThreat(e)) gain = -80;
    float ang = atan2(e.pos.y - player.y, e.pos.x - player.x) - yaw;
    setVoice(voices[e.ch], min(gain, 6) + volDb(V_VOICE), sin(ang));
  }
}

void setVoice(Controller v, float gain, float pan) {
  if (v.hasControl(Controller.GAIN)) v.setGain(gain);
  if (v.hasControl(Controller.PAN)) v.setPan(pan);
  else if (v.hasControl(Controller.BALANCE)) v.setBalance(pan);
}

// =====================================================================
// RENDER
void render() {
  float dg = danger(threatD);
  float pulse = kickEnv * chaseLvl;
  float dgV = max(dg, chaseLvl * 0.4);
  background(9, 8, 4);

  float ht = millis() * 0.0004;
  float yawR = yaw + (noise(ht, 3.1) - 0.5) * 0.014 * HANDHELD;
  float pitchR = pitch + (noise(ht, 7.7) - 0.5) * 0.010 * HANDHELD;

  float fx = cos(yawR), fy = sin(yawR), rx = -fy, ry = fx;
  float shake = sq(dgV) * 6 + pulse * 5;
  float sway = cos(bobPhase) * (crouching ? 2 : 4);
  float ex = player.x + rx * sway + random(-shake, shake);
  float ey = player.y + ry * sway + random(-shake, shake);
  float ez = eyeH - abs(sin(bobPhase)) * (crouching ? 3 : 7);
  float peekE = peekAmt * peekAmt * (3 - 2 * peekAmt);
  // the torso tilts at the hips: the head swings out on an arc and drops a little
  float arm = leanArm(), side = peekOff.mag();
  float tilt = asin(constrain(side / arm, 0, 1)) * peekE;
  if (side > 0) {
    ex += peekOff.x / side * arm * sin(tilt);
    ey += peekOff.y / side * arm * sin(tilt);
    ez -= arm * (1 - cos(tilt));
  }
  float rollR = roll - peekDir * PEEK_ROLL * tilt / PEEK_ANGLE;   // roll > 0 tilts the head left

  // the lens pass zooms the center in by 'fe': widen the field of view to keep the same framing
  float aspectR = float(width) / height;
  float fe = 1 + LENS_FISHEYE * 0.25 * (aspectR * aspectR + 1);
  perspective(2 * atan(tan((fov - pulse * radians(2.5)) / 2) * fe), aspectR, 10, CELL * GRID * 1.5);
  float lx = cos(yawR) * cos(pitchR), ly = sin(yawR) * cos(pitchR), lz = sin(pitchR);
  camera(ex, ey, ez, ex + lx, ey + ly, ez + lz, rx * sin(rollR), ry * sin(rollR), -cos(rollR));
  camX = ex; camY = ey; camZ = ez;
  camDX = lx; camDY = ly; camDZ = lz;

  for (Enemy e : enemies) {
    PVector sp = lensWarp(screenX(e.pos.x, e.pos.y, 190), screenY(e.pos.x, e.pos.y, 190));
    e.sx = sp.x;
    e.sy = sp.y;
    e.inFront = (e.pos.x - ex) * lx + (e.pos.y - ey) * ly > 0;
  }

  PVector zAx = new PVector(-lx, -ly, -lz);
  PVector upV = new PVector(rx * sin(rollR), ry * sin(rollR), -cos(rollR));
  PVector xAx = upV.cross(zAx);
  xAx.normalize();
  PVector yAx = zAx.cross(xAx);
  yAx.normalize();

  float haze = 0.5 + localLight;
  noLights();
  shader(world);
  world.set("camPos", ex, ey, ez);
  world.set("camDir", lx, ly, lz);
  world.set("camRight", xAx.x, xAx.y, xAx.z);
  world.set("camUp", yAx.x, yAx.y, yAx.z);
  world.set("mapData", mapU, 4);
  world.set("gridSize", (float) GRID);
  world.set("cellSize", CELL);
  world.set("wallH", WALL_H);
  world.set("lampZ", WALL_H - 25);
  world.set("exposure", EXPOSURE_BASE * exposureAdapt);
  world.set("fogDist", FOG_DIST);
  world.set("fogColor", 0.016 * haze, 0.013 * haze, 0.007 * haze);
  world.set("volOn", VOLUMETRIC ? 1.0 : 0.0);
  world.set("flash", flashlightOn ? 2.5 * flicker : 0.0);
  world.set("glow", 0.22 * flicker);
  world.set("emissive", 0.0);

  textureWrap(REPEAT);
  shape(level);
  drawDecals();
  drawArrows();
  drawExit();
  drawPanels();
  drawCerts();
  for (Enemy e : enemies) drawEnemy(e);
  resetShader();

  drawDrops3D();
  drawCans3D();
  drawPizzas();
  drawXray();
  drawViewModel3D();

  begin2D();
  applyLens();                       // 1. the player's eye: fish-eye, grain, micro-blur
  drawOverlay(dgV, pulse);           // 2. camcorder overlay + on-screen text
  applyPost(dgV, spotFlash * 0.5);   // 3. the camcorder itself
  drawHUD();                         // 4. gameplay HUD on top
  end2D();
}

void applyLens() {
  lens.set("time", millis() / 1000.0);
  lens.set("fisheye", LENS_FISHEYE);
  lens.set("aspect", width / (float) height);
  lens.set("grain", LENS_GRAIN);
  lens.set("soft", LENS_SOFT);
  filter(lens);
}

// where a point of the undistorted 3D frame ends up on screen after the lens pass
PVector lensWarp(float x, float y) {
  float asp = width / (float) height;
  float edge = 1 + LENS_FISHEYE * 0.25 * (asp * asp + 1);
  float sx = x / width - 0.5, sy = y / height - 0.5;
  float cx = sx, cy = sy;
  for (int k = 0; k < 5; k++) {
    float f = (1 + LENS_FISHEYE * (sq(cx * asp) + sq(cy))) / edge;
    cx = sx / f;
    cy = sy / f;
  }
  return new PVector((cx + 0.5) * width, (cy + 0.5) * height);
}

void drawPanels() {
  world.set("emissive", 2.4);
  textureWrap(CLAMP);
  noStroke();
  int pi = cellOf(player.x), pj = cellOf(player.y);
  float z = WALL_H - 5, hw = CELL * 0.28, hh = CELL * 0.14;
  for (int i = max(0, pi - 6); i <= min(GRID - 1, pi + 6); i++) {
    for (int j = max(0, pj - 6); j <= min(GRID - 1, pj + 6); j++) {
      if (solid[i][j]) continue;
      float p = lampP[i][j];
      float cx = (i + 0.5) * CELL, cy = (j + 0.5) * CELL;
      tint(lerp(12, 255, p), lerp(11, 245, p), lerp(9, 205, p));
      beginShape(QUADS);
      texture(panelTex);
      vertex(cx - hw, cy - hh, z, 0, 0);
      vertex(cx + hw, cy - hh, z, 1, 0);
      vertex(cx + hw, cy + hh, z, 1, 1);
      vertex(cx - hw, cy + hh, z, 0, 1);
      endShape();
    }
  }
  noTint();
  flush();
}

void drawEnemy(Enemy e) {
  float d = dist(player.x, player.y, e.pos.x, e.pos.y);
  if (d > CELL * 12) return;
  float dg = danger(d);
  boolean stunned = millis() < e.stunUntil;
  float s = 300;
  float base = 40;
  float glitch = stunned ? 35 : 60 * sq(max(dg, chaseLvl * 0.5));
  int strips = 14;

  world.set("emissive", stunned ? 0.6 : 0.18 + 0.25 * dg + 0.15 * chaseLvl);
  textureWrap(CLAMP);
  noStroke();
  float away = constrain((abs(angleDiff(e.face, atan2(player.y - e.pos.y, player.x - e.pos.x))) - VIEW_HALF) / 0.5, 0, 1);
  if (stunned) tint(130, 180, 255);
  else if (away > 0) tint(lerp(255, 105, away), lerp(255, 100, away), lerp(255, 95, away));
  else noTint();
  pushMatrix();
  translate(e.pos.x, e.pos.y, 0);
  rotateZ(atan2(player.y - e.pos.y, player.x - e.pos.x));
  for (int k = 0; k < strips; k++) {
    float v0 = k / (float) strips, v1 = (k + 1) / (float) strips;
    float off = 0;
    if (stunned) {
      if (random(1) < 0.5) off = random(-glitch, glitch);
    } else if (glitch > 2 && noise(k * 1.3 + 50 + e.ch * 9, millis() * 0.008) > 0.95 - 0.5 * max(dg, chaseLvl * 0.5)) {
      off = (noise(k * 0.7 + e.ch * 5, millis() * 0.012) - 0.5) * 2 * glitch;
    }
    float zTop = base + s - v0 * s, zBot = base + s - v1 * s;
    beginShape(QUADS);
    texture(faces[e.ch]);
    vertex(0,  s / 2 + off, zTop, 0, v0);
    vertex(0, -s / 2 + off, zTop, 1, v0);
    vertex(0, -s / 2 + off, zBot, 1, v1);
    vertex(0,  s / 2 + off, zBot, 0, v1);
    endShape();
  }
  popMatrix();
  noTint();
  flush();
}

void begin2D() {
  hint(DISABLE_DEPTH_TEST);
  camera();
  perspective();
  noLights();
}

void end2D() {
  hint(ENABLE_DEPTH_TEST);
}

void applyPost(float dg, float hit) {
  post.set("time", millis() / 1000.0);
  post.set("danger", dg);
  post.set("hit", hit);
  post.set("gain", state == PLAYING ? camGain : 0.3);
  post.set("vhs", state == MENU ? max(VHS_AMOUNT, 0.6) : VHS_AMOUNT);
  post.set("fisheye", OSD_FISHEYE);
  post.set("aspect", width / (float) height);
  filter(post);
}

// =====================================================================
// 2D EFFECTS AROUND THE VIEW MODEL (matched to the lens)
void drawViewFx() {
  int now = millis();
  if (useType >= 0) {
    float t = (now - useStart) / (float) USE_MS[useType];
    float c = constrain((t - 0.2) / 0.65, 0, 1);
    if (c > 0 && c < 1 && random(1) < 30 * frameDt) {
      PVector bp = lensWarp(biteSX, biteSY);
      spawnParticle(bp.x, bp.y, useType);
    }
  }
  if (now < fireUntil) {
    float k = 1 - (fireUntil - now) / 350.0;
    PVector tip = lensWarp(tipSX, tipSY);
    float tx = width / 2 + random(-30, 30), ty = height / 2 + random(-20, 20);
    if (taserHit && boltEnemy != null && boltEnemy.inFront) {
      tx = constrain(boltEnemy.sx, 0, width);
      ty = constrain(boltEnemy.sy, 0, height);
    }
    drawBolt(tip.x, tip.y, tx, ty);
    noStroke();
    fill(120, 190, 255, 90 * (1 - k));
    rect(0, 0, width, height);
  }
  drawParticles();
}

void drawBolt(float x0, float y0, float x1, float y1) {
  int n = 12;
  float[] px = new float[n + 1], py = new float[n + 1];
  for (int k = 0; k <= n; k++) {
    float t = k / (float) n;
    float j = (k == 0 || k == n) ? 0 : 22;
    px[k] = lerp(x0, x1, t) + random(-j, j);
    py[k] = lerp(y0, y1, t) + random(-j, j);
  }
  noFill();
  for (int pass = 0; pass < 2; pass++) {
    if (pass == 0) {
      stroke(90, 170, 255, 180);
      strokeWeight(8);
    } else {
      stroke(235, 245, 255);
      strokeWeight(2.5);
    }
    beginShape();
    for (int k = 0; k <= n; k++) vertex(px[k], py[k]);
    endShape();
  }
  noStroke();
}

void spawnParticle(float x, float y, int type) {
  int c;
  if (type == LAGRIMAS) c = color(90, 160, 255);
  else if (type == MONSTER) c = color(215, 235, 255);
  else if (type == SALADA) {
    int[] fr = {color(170, 30, 30), color(105, 140, 40), color(215, 180, 70), color(205, 110, 30)};
    c = fr[(int) random(fr.length)];
  } else if (type == CESTA) c = color(225, 220, 205);
  else c = color(170, 100, 35);
  parts.add(new Particle(x + random(-30, 30), y + random(-10, 10), random(-90, 90), random(-140, 10), c, random(3, 8)));
}

void drawParticles() {
  noStroke();
  for (int k = parts.size() - 1; k >= 0; k--) {
    Particle p = parts.get(k);
    p.vy += 900 * frameDt;
    p.x += p.vx * frameDt;
    p.y += p.vy * frameDt;
    p.life -= frameDt * 1.2;
    if (p.life <= 0 || p.y > height + 20) {
      parts.remove(k);
      continue;
    }
    fill(p.col, 255 * p.life);
    rect(p.x, p.y, p.sz, p.sz);
  }
}

// =====================================================================
// OVERLAY (before the camera filter): screen effects + the camcorder's own on-screen display
void drawOverlay(float dg, float pulse) {
  rectMode(CORNER);
  noStroke();
  if (dg > 0) {
    float beat = pow(abs(sin(millis() * 0.001 * PI * (1 + 2.5 * dg))), 8);
    fill(160, 0, 0, dg * (60 + 90 * beat));
    rect(0, 0, width, height);
  }
  if (pulse > 0.01) {
    noFill();
    stroke(200, 0, 0, 140 * pulse);
    strokeWeight(70);
    rect(0, 0, width, height);
    noStroke();
  }
  if (spotFlash > 0) {
    fill(255, 40, 30, 120 * spotFlash);
    rect(0, 0, width, height);
  }
  if (millis() < ghostUntil) {
    fill(80, 140, 255, 32 + 14 * sin(millis() * 0.004));
    rect(0, 0, width, height);
  }
  drawViewFx();
  float fadeIn = 1 - constrain(survived / 1.5, 0, 1);
  if (fadeIn > 0) {
    fill(0, 255 * fadeIn);
    rect(0, 0, width, height);
  }

  // viewfinder corners
  float m = 40, L = 46;
  stroke(255, 140);
  strokeWeight(3);
  noFill();
  line(m, m, m + L, m);                          line(m, m, m, m + L);
  line(width - m, m, width - m - L, m);          line(width - m, m, width - m, m + L);
  line(m, height - m, m + L, height - m);        line(m, height - m, m, height - m - L);
  line(width - m, height - m, width - m - L, height - m);
  line(width - m, height - m, width - m, height - m - L);
  noStroke();

  textFont(fontMono);
  if ((millis() / 600) % 2 == 0) {
    fill(225, 30, 30);
    ellipse(width - 168, 72, 16, 16);
  }
  textAlign(LEFT, CENTER);
  textSize(24);
  osdText("REC", width - 150, 70, color(255, 215));

  textSize(20);
  textAlign(LEFT, BOTTOM);
  osdText(nf(day(), 2) + " " + MESES[month() - 1] + " " + year() + "   "
    + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2), 70, height - 62, color(255, 215));
  textAlign(RIGHT, BOTTOM);
  osdText("SP", width - 130, height - 62, color(255, 215));
  drawBattery(width - 118, height - 84, dg);

  drawOsd();
}

// camcorder-style text: white with a soft drop shadow, part of the image
void osdText(String s, float x, float y, int c) {
  fill(0, 120);
  text(s, x + 2, y + 2);
  fill(c);
  text(s, x, y);
}

void drawBattery(float x, float y, float dg) {
  noFill();
  stroke(0, 110);
  strokeWeight(2);
  rect(x + 2, y + 2, 44, 20);
  stroke(255, 215);
  rect(x, y, 44, 20);
  noStroke();
  fill(255, 215);
  rect(x + 44, y + 6, 4, 8);
  boolean blink = dg > 0.5 && (millis() / 250) % 2 == 0;
  for (int k = 0; k < 3; k++) {
    if (k == 2 && blink) continue;
    rect(x + 4 + k * 13, y + 4, 10, 12);
  }
}

// top-left on-screen display: mode, time, objectives, buffs
void drawOsd() {
  int now = millis();
  float x = 72, y = 74;
  int white = color(255, 225), dim = color(255, 165);
  textFont(fontMono);
  textAlign(LEFT, CENTER);

  textSize(19);
  osdText(gameMode == ENDLESS ? "ENDLESS  " + rosterTitle() : dayLabel() + "  " + rosterTitle(), x, y, white);
  textSize(34);
  osdText(fmtTime(survived), x, y + 36, white);

  float ly = y + 72;
  textSize(15);
  if (gameMode == ENDLESS) {
    osdText("MELHOR  " + fmtTime(best), x, ly, dim);
  } else {
    for (int k = 0; k < certsPlaced; k++) {           // certificate pips: filled = taken, smaller = the extra
      boolean extra = k >= certsRequired;
      float pw = extra ? 9 : 12, ph = extra ? 12 : 16;
      float px = x + k * 18, py = ly - ph / 2;
      noFill();
      strokeWeight(2);
      stroke(0, 110);
      rect(px + 2, py + 2, pw, ph);
      stroke(255, 220);
      rect(px, py, pw, ph);
      noStroke();
      if (k < certsTaken) {
        fill(255, 225);
        rect(px + 3, py + 3, pw - 6, ph - 6);
      }
    }
    float tx = x + certsPlaced * 18 + 8;
    if (exitOpen) {
      if ((now / 450) % 2 == 0) osdText("► SAÍDA ABERTA", tx, ly, white);
    } else {
      osdText("CERTIFICADOS", tx, ly, dim);
    }
  }

  int[] until = {energyUntil, swiftUntil, ghostUntil, fedUntil, pilhadoUntil};
  int[] dur = {BUFF_MS[COXINHA], BUFF_MS[SALADA], BUFF_MS[LAGRIMAS], BUFF_MS[CESTA], BUFF_MS[MONSTER]};
  String[] label = {"ENERGIA", "LEVEZA", "INVISÍVEL", "ABASTECIDO", "PILHADO"};
  int[] col = {color(255, 175, 70), color(160, 225, 110), color(130, 175, 255), color(240, 215, 150), color(225, 240, 255)};
  float by = ly + 32;
  for (int k = 0; k < until.length; k++) {
    int left = until[k] - now;
    if (left <= 0) continue;
    int lit = ceil(left / (float) dur[k] * 10);
    textSize(14);
    osdText(label[k], x, by, white);
    noStroke();
    for (int s = 0; s < 10; s++) {
      float sx = x + 122 + s * 9;
      fill(0, 100);
      rect(sx + 2, by - 3, 6, 9);
      fill(s < lit ? col[k] : color(255, 45));
      rect(sx, by - 5, 6, 9);
    }
    by += 24;
  }
}

// =====================================================================
// HUD (after the filter)
void hudSlab(float x, float y, float w, float h) {
  noStroke();
  fill(0, 205);
  rect(x, y, w, h);
  stroke(255, 28);
  strokeWeight(1);
  noFill();
  rect(x + 0.5, y + 0.5, w - 1, h - 1);
  noStroke();
}

void drawHazard(float x, float y, float w, float h) {
  noStroke();
  fill(230, 180, 20);
  rect(x, y, w, h);
  fill(10);
  float sw = 12;
  for (float s = x - h; s < x + w; s += sw * 2) {
    float a0 = constrain(s, x, x + w), a1 = constrain(s + sw, x, x + w);
    float b0 = constrain(s + h, x, x + w), b1 = constrain(s + sw + h, x, x + w);
    quad(a0, y + h, a1, y + h, b1, y, b0, y);
  }
}

String rosterTitle() {
  if (gameMode == FUGA) {
    if (runDay == RECUP_DAY) return "TODOS";
    if (runDay == FINAL_DAY) return "VS. 6";
    return NAMES[DAY_ORDER[runDay]].toUpperCase();
  }
  return runEntry >= 6 ? "TODOS" : NAMES[runEntry].toUpperCase();
}

String dayLabel() {
  return runDay == RECUP_DAY ? "RECUPERAÇÃO" : "DIA " + (runDay + 1);
}

void drawHUD() {
  rectMode(CORNER);
  imageMode(CORNER);
  noStroke();
  int now = millis();

  drawStamina();
  drawInventory();

  float cx = width / 2, cy = height / 2;
  stroke(235, 150);
  strokeWeight(2);
  line(cx - 9, cy, cx - 4, cy);
  line(cx + 4, cy, cx + 9, cy);
  line(cx, cy - 9, cx, cy - 4);
  line(cx, cy + 4, cx, cy + 9);
  noStroke();

  drawEye(width / 2, 86);

  if (gameMode == FUGA && nearCert >= 0) {
    textFont(fontHud);
    textSize(22);
    String p = "[E]  PEGAR CERTIFICADO";
    float tw = textWidth(p);
    fill(0, 200);
    rect(width / 2 - tw / 2 - 16, height / 2 + 40, tw + 32, 36);
    fill(225, 200, 120);
    rect(width / 2 - tw / 2 - 16, height / 2 + 40, 6, 36);
    fill(235, 230, 215);
    textAlign(CENTER, CENTER);
    text(p, width / 2, height / 2 + 57);
  } else if (peekSide == 0 && (peekL != null || peekR != null)) {
    textFont(fontMono);
    textSize(13);
    fill(235, 230, 215, 140);
    textAlign(CENTER, CENTER);
    text((peekL != null ? "[Q] <  " : "") + "ESPREITAR" + (peekR != null ? "  > [E]" : ""), width / 2, height / 2 + 44);
  }

  if (now < msgUntil) {
    float a = constrain((msgUntil - now) / 400.0, 0, 1);
    textFont(fontHud);
    textSize(24);
    float tw = textWidth(msg);
    float my = height / 2 + 100;
    fill(0, 215 * a);
    rect(width / 2 - tw / 2 - 18, my, tw + 36, 40);
    fill(170, 20, 15, 255 * a);
    rect(width / 2 - tw / 2 - 18, my, 6, 40);
    fill(235, 230, 215, 255 * a);
    textAlign(CENTER, CENTER);
    text(msg, width / 2, my + 19);
  }

  // ---- intro card
  if (survived < graceTime + 1) {
    float a = 255 * constrain(min(survived * 2, (graceTime + 1 - survived) * 2), 0, 1);
    textAlign(CENTER, CENTER);
    textFont(fontHud);
    if (gameMode == FUGA) {
      textSize(64);
      fill(235, 230, 215, a);
      text(dayLabel(), width / 2, height / 2 - 150);
      textSize(30);
      fill(200, 40, 30, a);
      String sub = runDay == RECUP_DAY ? "TODOS ELES  —  NO ESCURO"
        : (runDay == FINAL_DAY ? "VS. 6  —  TODOS ELES" : rosterTitle() + "  —  " + NICKS[DAY_ORDER[runDay]].toUpperCase());
      text(sub, width / 2, height / 2 - 100);
      textFont(fontMono);
      textSize(15);
      fill(200, a);
      String hint = runDay == RECUP_DAY ? "UM CERTIFICADO. NENHUMA LUZ. ENCONTRE A SAÍDA."
        : (runDay == FINAL_DAY ? "COLETE OS 3 CERTIFICADOS E ENCONTRE A SAÍDA" : "SIGA AS SETAS");
      text(hint, width / 2, height / 2 - 62);
    } else {
      textSize(46);
      fill(235, 230, 215, a);
      text(runEntry >= 6 ? "TODOS ACORDARAM... CORRA!" : rosterTitle() + " ACORDOU... CORRA!", width / 2, height / 2 - 130);
      textFont(fontMono);
      textSize(15);
      fill(200, a);
      text("SHIFT CORRER   C AGACHAR   1-5 COMER/BEBER   Q TASER   G LATA   Q/E NA QUINA ESPREITAR   ESC PAUSA", width / 2, height / 2 - 88);
    }
  }

  drawToasts();
}

// The Eye: shows the most alarming state among the nerdolas (Isa only once she's close)
void drawEye(float cx, float cy) {
  int now = millis();
  boolean huntingAny = false, chaseAny = false, stunnedAny = false, confusedAny = false, searchAny = false;
  for (Enemy e : enemies) {
    boolean hidden = hiddenThreat(e);
    if (now < e.stunUntil) {
      if (!hidden) stunnedAny = true;
      continue;
    }
    if (e.ai == CHASE && e.sees) huntingAny = true;
    if (hidden) continue;
    if (e.ai == CHASE) chaseAny = true;
    if (now < e.confusedUntil) confusedAny = true;
    if (e.ai == SEARCH) searchAny = true;
  }
  float target = 0, lx = 0, ly = 0, shake = 0;
  int iris = color(120);
  boolean veins = false;
  if (survived < graceTime) {
    target = 0;
  } else if (huntingAny) {
    target = 1;
    iris = color(190, 15, 10);
    shake = 2.5;
    veins = true;
  } else if (chaseAny) {
    target = 0.8;
    iris = color(190, 80, 15);
    lx = sin(now * 0.005) * 0.35;
    veins = true;
  } else if (stunnedAny) {
    target = 0.6;
    iris = color(80, 160, 255);
    lx = cos(now * 0.025) * 0.75;
    ly = sin(now * 0.025) * 0.5;
    shake = 3;
    veins = true;
  } else if (confusedAny) {
    target = 0.45;
    iris = color(110, 150, 210);
    lx = cos(now * 0.004) * 0.8;
    ly = sin(now * 0.0052) * 0.5;
  } else if (searchAny) {
    target = 0.5;
    iris = color(180, 140, 40);
    lx = ((now / 650) % 2 == 0) ? -0.8 : 0.8;
    ly = ((now / 1300) % 2 == 0) ? 0.2 : -0.1;
  }
  if (target > 0 && now > nextBlink) {
    blinkUntil = now + 120;
    nextBlink = now + (int) random(1600, 4200);
  }
  if (now < blinkUntil && !huntingAny) target = 0;
  eyeOpen = lerp(eyeOpen, target, 1 - exp(-frameDt * 16));
  eyeLX = lerp(eyeLX, lx, 1 - exp(-frameDt * 12));
  eyeLY = lerp(eyeLY, ly, 1 - exp(-frameDt * 12));

  float w = 112, h = 30;
  pushMatrix();
  translate(cx + random(-shake, shake), cy + random(-shake, shake));
  float op = eyeOpen * h;
  if (op > 1.5) {
    noStroke();
    fill(huntingAny ? color(225, 200, 185) : color(200, 195, 180));
    eyeShape(w, op);
    if (veins) {
      stroke(150, 15, 15, 200);
      strokeWeight(1.4);
      for (int k = 0; k < 6; k++) {
        float side = k < 3 ? -1 : 1;
        float x0 = side * w * 0.46, y0 = (k % 3 - 1) * op * 0.25;
        float x1 = side * w * 0.2, y1 = y0 * 0.4 + (noise(k, now * 0.001) - 0.5) * 6;
        float mx = (x0 + x1) / 2, my = (y0 + y1) / 2 + (k % 2 == 0 ? 3 : -3);
        line(x0, y0, mx, my);
        line(mx, my, x1, y1);
      }
      noStroke();
    }
    float r = h * 0.72;
    float ix = eyeLX * w * 0.15, iy = eyeLY * op * 0.3;
    float ih = min(r * 2, op * 1.7);
    fill(iris);
    ellipse(ix, iy, r * 2, ih);
    float pr = huntingAny ? r * (0.35 + 0.15 * abs(sin(now * 0.02))) : r * 0.75;
    fill(5);
    ellipse(ix, iy, pr, min(pr, ih * 0.9));
    fill(240, 200);
    rect(ix + r * 0.25, iy - ih * 0.3, 4, 4);
    noFill();
    stroke(8);
    strokeWeight(5);
    eyeShape(w, op);
    strokeWeight(3);
    for (int k = 0; k < 7; k++) {
      float t = (k + 1) / 8.0;
      float x = lerp(-w / 2, w / 2, t);
      float y = -3.9 * op * t * (1 - t);
      line(x, y, x * 1.08, y - 9);
    }
    noStroke();
  } else {
    noFill();
    for (int pass = 0; pass < 2; pass++) {
      stroke(pass == 0 ? color(10, 200) : color(215, 205, 185));
      strokeWeight(pass == 0 ? 9 : 4);
      bezier(-w / 2, 0, -w / 4, 10, w / 4, 10, w / 2, 0);
      strokeWeight(pass == 0 ? 6 : 2.5);
      for (int k = 0; k < 7; k++) {
        float t = (k + 1) / 8.0;
        float x = lerp(-w / 2, w / 2, t);
        float y = 30 * t * (1 - t);
        line(x, y, x * 1.05, y + 9);
      }
    }
    noStroke();
  }
  popMatrix();

  String sub = "";
  if (crouching) sub = "AGACHADO";
  if (peekSide != 0) sub = sub.length() > 0 ? sub + " / ESPREITANDO" : "ESPREITANDO";
  if (!flashlightOn && playerExpo < 0.2) sub = sub.length() > 0 ? sub + " / NAS SOMBRAS" : "NAS SOMBRAS";
  if (now < ghostUntil) sub = sub.length() > 0 ? sub + " / INVISÍVEL" : "INVISÍVEL";
  if (sub.length() > 0) {
    textFont(fontMono);
    textSize(12);
    float tw = textWidth(sub);
    fill(0, 170);
    rect(cx - tw / 2 - 8, cy + h + 16, tw + 16, 20);
    fill(220);
    textAlign(CENTER, CENTER);
    text(sub, cx, cy + h + 25);
  }
}

void drawStamina() {
  int now = millis();
  boolean energized = now < energyUntil, fed = now < fedUntil;
  float smax = staminaMax();
  int segs = round((fed ? 30 : 20) * pizzaMul());
  float sw = 15, gap = 3;
  float bw = segs * (sw + gap) - gap;
  float bx = width / 2 - bw / 2, by = height - 64;
  hudSlab(bx - 8, by - 8, bw + 16, 26);
  int lit = ceil(stamina / smax * segs - 0.001);
  boolean blinkOff = exhausted && (now / 160) % 2 == 0;
  for (int k = 0; k < segs; k++) {
    if (k < lit && !blinkOff) {
      if (energized) fill(255, 160, 30);
      else if (exhausted) fill(200, 25, 15);
      else if (fed) fill(235, 205, 140);
      else fill(225, 215, 180);
    } else {
      fill(255, 22);
    }
    rect(bx + k * (sw + gap), by, sw, 10);
  }
  textFont(fontMono);
  textSize(11);
  fill(150);
  textAlign(RIGHT, CENTER);
  text("FÔLEGO", bx - 16, by + 5);
}

void drawInventory() {
  // only what you're carrying (plus the one in your hands while you use it), packed and centered
  ArrayList<Integer> shown = new ArrayList<Integer>();
  for (int k = 0; k < ITEM_NAMES.length; k++) if (inv[k] > 0 || useType == k) shown.add(k);
  float slot = 72, x0 = width / 2 - slot * shown.size() / 2.0, y = height - 160;
  imageMode(CENTER);
  for (int n = 0; n < shown.size(); n++) {
    int k = shown.get(n);
    float x = x0 + n * slot + 4, sz = slot - 8;
    boolean has = inv[k] > 0;
    noStroke();
    fill(0, has ? 215 : 140);
    rect(x, y, sz, sz);
    stroke(useType == k ? color(200, 30, 20) : (has ? color(200, 190, 160) : color(60)));
    strokeWeight(3);
    noFill();
    rect(x, y, sz, sz);
    noStroke();
    tint(has ? 255 : 70);
    image(itemTex[k], x + sz / 2, y + sz / 2 + 2, 50, 50);
    noTint();
    fill(has ? color(225, 215, 180) : color(70));
    rect(x, y, 17, 17);
    fill(0);
    textFont(fontMono);
    textSize(12);
    textAlign(CENTER, CENTER);
    text(ITEM_KEYS[k], x + 8.5, y + 7.5);
    if (has) {
      textFont(fontHud);
      textSize(17);
      fill(235);
      textAlign(RIGHT, BOTTOM);
      text("x" + inv[k], x + sz - 4, y + sz + 1);
    }
  }
  imageMode(CORNER);
}

void eyeShape(float w, float op) {
  beginShape();
  vertex(-w / 2, 0);
  bezierVertex(-w / 4, -op * 1.3, w / 4, -op * 1.3, w / 2, 0);
  bezierVertex(w / 4, op * 1.3, -w / 4, op * 1.3, -w / 2, 0);
  endShape(CLOSE);
}

void drawToasts() {
  if (toastQueue.isEmpty()) return;
  int now = millis();
  float t = (now - toastStart) / 1000.0;
  if (t > 3.2) {
    toastQueue.remove(0);
    toastStart = now;
    return;
  }
  int id = toastQueue.get(0);
  float slide = t < 0.3 ? t / 0.3 : (t > 2.9 ? 1 - (t - 2.9) / 0.3 : 1);
  slide = slide * slide * (3 - 2 * slide);
  float w = 420, h = 80;
  float x = width + 10 - (w + 50) * slide, y = 120;
  rectMode(CORNER);
  hudSlab(x, y, w, h);
  drawHazard(x, y, w, 7);
  fill(255, 200, 40);
  noStroke();
  drawStar(x + 40, y + h / 2 + 3, 20);
  textFont(fontMono);
  textAlign(LEFT, TOP);
  textSize(12);
  text("CONQUISTA DESBLOQUEADA", x + 72, y + 16);
  textFont(fontHud);
  textSize(24);
  fill(240);
  text(ACH_NAME[id].toUpperCase(), x + 72, y + 36);
}

void drawStar(float x, float y, float r) {
  beginShape();
  for (int k = 0; k < 10; k++) {
    float a = -HALF_PI + k * PI / 5;
    float rr = k % 2 == 0 ? r : r * 0.45;
    vertex(x + cos(a) * rr, y + sin(a) * rr);
  }
  endShape(CLOSE);
}

void drawRunAch(float y, float a, boolean dark) {
  if (runAch.isEmpty()) return;
  textFont(fontUI);
  textAlign(CENTER, TOP);
  textSize(18);
  fill(dark ? color(150, 100, 0, 255 * a) : color(255, 210, 90, 255 * a));
  text("★ Conquistas desbloqueadas ★", width / 2, y);
  String line = "";
  for (int k = 0; k < runAch.size(); k++) line += (k > 0 ? "   ·   " : "") + ACH_NAME[runAch.get(k)];
  textSize(16);
  fill(dark ? color(40, 255 * a) : color(240, 255 * a));
  text(line, width / 2 - 560, y + 28, 1120, 80);
}

// =====================================================================
// END SCREENS
void drawDeath() {
  begin2D();
  background(0);
  imageMode(CENTER);
  float t = (millis() - deathMs) / 1000.0;
  float hit = 0;
  if (t < 1.0) {
    hit = 1 - t;
    staticAmp.setValue(0.3 * (1 - t));
    boom.setFrequency(40);
    boom.setAmplitude(0.9 * (1 - t));
    for (int k = 0; k < 3; k++) {
      sting[k].setFrequency(STING_F[k] * (1 - 0.4 * t));
      sting[k].setAmplitude(0.08 * (1 - t));
    }
    float sz = lerp(height * 0.6, height * 1.6, t);
    boolean flash = random(1) < 0.3;
    tint(255, flash ? 40 : 255, flash ? 40 : 255);
    image(faces[killerCh], width / 2 + random(-25, 25), height / 2 + random(-25, 25), sz, sz);
    noTint();
  } else {
    staticAmp.setValue(0);
    boom.setAmplitude(0);
    for (Oscil o : sting) o.setAmplitude(0);
    if (voices[killerCh].isPlaying()) voices[killerCh].pause();
    float a = constrain((t - 1) / 0.7, 0, 1);
    float sz = height * (1.08 - 0.08 * a);
    tint(90 * a, 0, 0);
    image(faces[killerCh], width / 2, height / 2, sz, sz);
    noTint();
    textAlign(CENTER, CENTER);
    textFont(fontBig);
    textSize(90);
    fill(255, 255 * a);
    text("MORRESTE", width / 2, height / 2 - 110);
    textFont(fontUI);
    textSize(40);
    if (gameMode == ENDLESS) {
      text("Sobreviveu " + nf(survived, 0, 1) + "s", width / 2, height / 2 - 20);
      textSize(28);
      fill(newRecord ? color(255, 230, 120, 255 * a) : color(220, 255 * a));
      text(newRecord ? "NOVO RECORDE!" : "Recorde: " + nf(best, 0, 1) + "s", width / 2, height / 2 + 32);
    } else {
      text(dayLabel() + "  —  Certificados: " + certsTaken + "/" + certsPlaced, width / 2, height / 2 - 20);
      textSize(28);
      fill(220, 255 * a);
      text("Pego por " + NAMES[killerCh] + "  ·  " + fmtTime(survived), width / 2, height / 2 + 32);
    }
    textSize(20);
    fill(200, 255 * a);
    text("Itens coletados: " + itemsCollected + "     Consumidos: " + itemsUsed + "     Atordoamentos: " + stuns
      + "     Fugas: " + chasesEscaped, width / 2, height / 2 + 76);
    drawRunAch(height / 2 + 115, a, false);
    textSize(22);
    fill(200, 255 * a);
    text("[R] tentar de novo     [M] menu", width / 2, height - 80);
  }
  applyPost(t < 1 ? 1 : 0.2, hit);
  drawToasts();
  imageMode(CORNER);
  end2D();
}

void drawWin() {
  begin2D();
  float t = (millis() - winMs) / 1000.0;
  float a = constrain((t - 0.4) / 0.8, 0, 1);
  noStroke();
  for (int k = 0; k < 30; k++) {
    fill(lerpColor(color(150, 190, 230), color(245, 235, 205), k / 29.0));
    rect(0, k * height / 30.0, width, height / 30.0 + 1);
  }
  if (t > 2) {
    imageMode(CENTER);
    boolean tw = random(1) < 0.04;
    tint(255, 40 + (tw ? 60 : 0));
    image(faces[winFaceCh], width * 0.88 + (tw ? random(-6, 6) : 0), height * 0.78, 90, 90);
    noTint();
    imageMode(CORNER);
  }
  textAlign(CENTER, CENTER);
  textFont(fontBig);
  textSize(80);
  fill(30, 255 * a);
  text(runDay == RECUP_DAY ? "RECUPERAÇÃO CONCLUÍDA" : (runDay == FINAL_DAY ? "SEMANA CONCLUÍDA" : "DIA " + (runDay + 1) + " CONCLUÍDO"),
    width / 2, height / 2 - 160);
  textFont(fontUI);
  textSize(34);
  text("Tempo: " + fmtTime(survived) + "     Certificados: " + certsTaken + "/" + certsPlaced, width / 2, height / 2 - 75);
  textSize(24);
  int h = hoursValidated();
  fill(runDay < DAYS && h > winHoursBefore ? color(30, 120, 40, 255 * a) : color(60, 255 * a));
  if (runDay < DAYS) text("Horas validadas: " + h + "h/36h" + (h > winHoursBefore ? "   (+" + (h - winHoursBefore) + "h)" : ""), width / 2, height / 2 - 30);
  else text(runDay == RECUP_DAY ? "Aprovado na recuperação." : "Os certificados do VS. 6 não contam horas.", width / 2, height / 2 - 30);
  if (runDay < DAYS) {
    fill(170, 110, 0, 255 * a);
    if (runDay + 1 < DAYS) text("★ Desbloqueado: Dia " + (runDay + 2) + " — " + NAMES[DAY_ORDER[runDay + 1]], width / 2, height / 2 + 8);
    else text("★ Desbloqueado: Dia 7 — VS. 6", width / 2, height / 2 + 8);
  }
  drawRunAch(height / 2 + 80, a, true);
  textSize(22);
  fill(60, 255 * a);
  text(emailPending ? "[ENTER] você tem um novo e-mail" : "[R] jogar de novo     [M] menu", width / 2, height - 80);
  float fl = 1 - constrain(t / 0.9, 0, 1);
  if (fl > 0) {
    fill(255, 255 * fl);
    rect(0, 0, width, height);
  }
  applyPost(0.05, 0);
  drawToasts();
  end2D();
}

String emailBody() {
  if (emailSuccess) {
    return "Prezado,\n\nSeu pedido de horas complementares foi revisado pela Escola Politécnica.\n"
      + "Com um total de 36h/36h validadas, seu certificado de horas complementares da POLIWEEK foi aceito integralmente.\n\n"
      + "Atenciosamente,\nAndrey";
  }
  return "Prezado,\n\nSeu pedido de horas complementares foi revisado pela Escola Politécnica.\n"
    + "Porém, como apenas um total de " + hoursValidated() + "h/36h validadas, não estaremos emitindo seu certificado de horas complementares da POLIWEEK.\n\n"
    + "Atenciosamente,\nAndrey";
}

void drawEmail() {
  begin2D();
  float t = (millis() - emailMs) / 1000.0;
  background(0);
  imageMode(CORNER);
  float sc = max(width / (float) pucprBg.width, height / (float) pucprBg.height) * 1.08;
  tint(165);
  image(pucprBg, width / 2 - pucprBg.width * sc / 2 + sin(t * 0.2) * 8, height / 2 - pucprBg.height * sc / 2,
    pucprBg.width * sc, pucprBg.height * sc);
  noTint();
  noStroke();
  fill(0, 80);
  rect(0, 0, width, height);

  String body = emailBody();
  int nChars = (int) constrain((t - 0.8) * 55, 0, body.length());
  boolean done = nChars >= body.length();

  pushMatrix();
  translate(width / 2, height / 2 - 10);
  rotate(-0.045);
  float cw = 860, chh = 560;
  float x0 = -cw / 2, y0 = -chh / 2;
  fill(0, 90);
  rect(x0 + 12, y0 + 16, cw, chh);
  fill(248, 247, 243);
  rect(x0, y0, cw, chh);
  fill(165, 28, 40);
  rect(x0, y0, cw, 46);
  fill(255);
  textFont(fontUI);
  textSize(18);
  textAlign(LEFT, CENTER);
  text("Webmail PUCPR  —  Caixa de entrada", x0 + 20, y0 + 23);
  textFont(fontMail);
  textSize(15);
  textAlign(LEFT, TOP);
  fill(110);
  text("De:", x0 + 30, y0 + 64);
  text("Para:", x0 + 30, y0 + 88);
  text("Assunto:", x0 + 30, y0 + 112);
  fill(30);
  text("Andrey Cabral <andrey.cabral@pucpr.br>", x0 + 115, y0 + 64);
  text("você <aluno@pucpr.edu.br>", x0 + 115, y0 + 88);
  text("Horas complementares — POLIWEEK", x0 + 115, y0 + 112);
  stroke(210);
  strokeWeight(1);
  line(x0 + 30, y0 + 142, x0 + cw - 30, y0 + 142);
  noStroke();
  fill(25);
  textSize(19);
  textLeading(28);
  text(body.substring(0, nChars) + (done || (millis() / 300) % 2 == 0 ? "" : "|"), x0 + 40, y0 + 162, cw - 80, chh - 190);
  if (done) {
    pushMatrix();
    translate(cw / 2 - 175, chh / 2 - 95);
    rotate(-0.22);
    int sc2 = emailSuccess ? color(30, 140, 50) : color(185, 25, 25);
    stroke(sc2);
    strokeWeight(5);
    noFill();
    rectMode(CENTER);
    rect(0, 0, 260, 70);
    rectMode(CORNER);
    noStroke();
    fill(sc2);
    textFont(fontHud);
    textSize(40);
    textAlign(CENTER, CENTER);
    text(emailSuccess ? "DEFERIDO" : "INDEFERIDO", 0, 0);
    popMatrix();
  }
  popMatrix();

  if (done) {
    textAlign(CENTER, CENTER);
    textFont(fontHud);
    textSize(28);
    float by = height - (emailFirst && emailSuccess ? 128 : 92);
    if (emailFirst) {
      String s = "7ª ESTRELA  —  ENDLESS DESBLOQUEADO";
      fill(255, 215, 90);
      drawStar(width / 2 - textWidth(s) / 2 - 30, by, 16);
      text(s, width / 2, by);
      by += 38;
    }
    if (emailSuccess) {
      String s = "8ª ESTRELA  —  RECUPERAÇÃO DESBLOQUEADA";
      fill(90, 220, 110);
      drawStar(width / 2 - textWidth(s) / 2 - 30, by, 16);
      text(s, width / 2, by);
    }
    textFont(fontMono);
    textSize(16);
    fill(230);
    text("[ENTER] continuar", width / 2, height - 46);
  }
  applyPost(0.04, 0);
  drawToasts();
  end2D();
}

// =====================================================================
// MENU (FNAF 2 style)
void drawMenu() {
  begin2D();
  background(0);
  float t = millis() / 1000.0;
  updateTwitches();
  menuFlicker = random(1) < 0.04 ? random(0.35, 0.8) : 1;

  imageMode(CORNER);
  tint(menuPage == 0 ? 45 : 25);
  image(menuImg, -20 + sin(t * 0.1) * 10, -10, width + 40, height + 20);
  noTint();

  if (menuPage == 0) drawMenuPreview();

  noStroke();
  rectMode(CORNER);
  for (int k = 0; k < 40; k++) {
    fill(0, max(0, 235 - k * 6));
    rect(k * 16, 0, 16, height);
  }

  drawStatic();
  if (menuPage == 0) drawMainMenu();
  else if (menuPage == 1) drawAchievementsPage();
  else drawCatalogue();

  float pk = (millis() - pageSwitchMs) / 200.0;           // page change: full-screen static flick
  if (pk < 1) drawSwitchStatic(0, 0, width, height, 0.7 * (1 - pk));

  applyPost(0.12 + menuStatic, menuStatic * 0.6);
  end2D();
}

// ---- transitions
void menuSelect(int s) {
  if (s == menuSel) return;
  menuSel = s;
  switchMs = millis();
  menuStatic = max(menuStatic, 0.16);
  if (s == 0) lineupMode = FUGA;
  if (s == 1) lineupMode = ENDLESS;
  lineShift = 0;
}

void menuPageTo(int p) {
  menuPage = p;
  pageStatic();
}

void pageStatic() {
  pageSwitchMs = millis();
  menuStatic = max(menuStatic, 0.18);
}

void drawSwitchStatic(float x, float y, float w, float h, float amt) {
  imageMode(CORNER);
  tint(255, 150 * amt);
  image(staticImg, x, y, w, h);
  noTint();
  noStroke();
  for (int k = 0; k < 7; k++) {
    float by = y + random(h), bh = random(2, 14);
    fill(random(1) < 0.5 ? 255 : 0, 90 * amt);
    rect(x, by, w, bh);
  }
}

boolean previewIsLineup() {
  return menuPage == 0 && (menuSel == 0 || (menuSel == 1 && endlessUnlocked));
}

// ---- right side: one preview per menu option
void drawMenuPreview() {
  float k = constrain((millis() - switchMs) / 220.0, 0, 1);
  pushMatrix();
  if (k < 1) translate(random(-12, 12) * (1 - k), 0);
  if (menuSel == 0) drawLineup();
  else if (menuSel == 1) {
    if (endlessUnlocked) drawLineup();
    else drawLockedPreview("ENDLESS", "Vença a semana da POLIWEEK para desbloquear.");
  } else if (menuSel == 2) {
    if (recupUnlocked) drawRecupPreview();
    else drawLockedPreview("???", "Valide 36h/36h na POLIWEEK para desbloquear.");
  } else if (menuSel == 3) drawCataloguePreview();
  else if (menuSel == 4) drawAchPreview();
  else drawExitPreview();
  popMatrix();
  if (k < 1) drawSwitchStatic(width * 0.42, 0, width * 0.58, height, 1 - k);
}

void previewLabel(String title, String sub) {
  float ly = lineY(0) + lineS(0) / 2 + 36;
  textFont(fontUI);
  textAlign(CENTER, CENTER);
  textSize(28);
  fill(235, 220 * menuFlicker);
  text(title, lineX(0), ly);
  textSize(16);
  fill(170);
  text(sub, lineX(0), ly + 30);
}

void updateTwitches() {
  int now = millis();
  int[] chars = lineupChars();
  int frontCh = chars[lineSel()];
  for (int k = 0; k < 7; k++) {
    if (now < twitchUntil[k]) continue;
    int kk = k < 6 ? k : -1;
    float rate = kk == frontCh ? 0.7 : 0.25;
    if (random(1) < rate * frameDt) {
      twitchUntil[k] = now + (int) random(60, 220);
      twDx[k] = random(-18, 18);
      twDy[k] = random(-10, 10);
      twRot[k] = random(-0.2, 0.2);
      twType[k] = (int) random(4);
    }
  }
}

int[] lineupChars() {
  if (lineupMode == ENDLESS) return new int[]{0, 1, 2, 3, 4, 5, -1};
  int n = unlockedDays();
  int[] r = new int[n];
  for (int k = 0; k < n; k++) r[k] = k < DAYS ? DAY_ORDER[k] : -1;
  return r;
}

int lineSel() {
  int n = lineupChars().length;
  return constrain(lineupMode == ENDLESS ? enSel : pwSel, 0, n - 1);
}

void setLineSel(int s) {
  if (lineupMode == ENDLESS) enSel = s;
  else pwSel = s;
}

float lineX(float p) { return width * 0.69 + p * 95; }
float lineY(float p) { return height * 0.56 - p * 36; }
float lineS(float p) { return 470 * pow(0.8, p); }

void drawLineup() {
  int[] chars = lineupChars();
  int n = chars.length;
  int sel = lineSel();
  lineShift *= exp(-frameDt * 7);
  if (abs(lineShift) < 0.001) lineShift = 0;
  for (int i = n - 1; i >= 0; i--) {
    int k = (sel + i) % n;
    float p = i + lineShift;
    float bright = 255 * pow(0.6, max(p, 0)) * (i == 0 ? menuFlicker : 1);
    float alpha = p < 0 ? 255 * constrain(1 + p, 0, 1) : 255;
    if (chars[k] >= 0) drawLineupFace(chars[k], chars[k], lineX(p), lineY(p), lineS(p), bright, alpha);
    else drawGroupFace(lineX(p), lineY(p), lineS(p), bright, alpha);
  }

  int ch = chars[sel];
  if (lineupMode == FUGA) {
    String sub = ch >= 0 ? NICKS[ch] : "Todos eles";
    if (dayBeaten[sel]) sub += sel < DAYS ? "   ·   ✓   ·   certificados " + dayCerts[sel] + "/" + CERTS_PER_DAY : "   ·   ✓";
    previewLabel((n > 1 ? "◄   " : "") + "DIA " + (sel + 1) + "  —  " + (ch >= 0 ? NAMES[ch].toUpperCase() : "VS. 6") + (n > 1 ? "   ►" : ""), sub);
  } else {
    previewLabel("◄   " + (ch >= 0 ? NAMES[ch].toUpperCase() : "TODOS") + "   ►", ch >= 0 ? NICKS[ch] : "Os seis ao mesmo tempo");
  }
}

void drawLineupFace(int tw, int ch, float x, float y, float sz, float bright, float alpha) {
  boolean twitching = millis() < twitchUntil[tw];
  float breathe = sin(millis() * 0.0011 + tw * 1.3);
  pushMatrix();
  translate(x, y + breathe * 3);
  if (twitching) {
    translate(twDx[tw], twDy[tw]);
    rotate(twType[tw] == 3 ? twRot[tw] * 1.6 : twRot[tw] * 0.4);
  } else {
    rotate(breathe * 0.008);
  }
  float s = sz * (twitching && twType[tw] == 2 ? 1.06 : 1);
  if (twitching && twType[tw] == 2) tint(bright, bright * 0.25, bright * 0.25, alpha);
  else tint(bright, alpha);
  noStroke();
  if (twitching && twType[tw] == 1) {
    int strips = 8;
    for (int st = 0; st < strips; st++) {
      float v0 = st / (float) strips, v1 = (st + 1) / (float) strips;
      float off = random(-s * 0.06, s * 0.06);
      beginShape(QUADS);
      texture(faces[ch]);
      vertex(-s / 2 + off, -s / 2 + v0 * s, 0, v0);
      vertex( s / 2 + off, -s / 2 + v0 * s, 1, v0);
      vertex( s / 2 + off, -s / 2 + v1 * s, 1, v1);
      vertex(-s / 2 + off, -s / 2 + v1 * s, 0, v1);
      endShape();
    }
  } else {
    imageMode(CENTER);
    image(faces[ch], 0, 0, s, s);
    imageMode(CORNER);
  }
  noTint();
  popMatrix();
}

// the VS. 6 / TODOS card: all six faces crammed together
void drawGroupFace(float x, float y, float sz, float bright, float alpha) {
  boolean twitching = millis() < twitchUntil[6];
  pushMatrix();
  translate(x, y);
  if (twitching) {
    translate(twDx[6], twDy[6]);
    rotate(twRot[6] * 0.4);
  }
  float f = sz * 0.36;
  imageMode(CENTER);
  for (int k = 0; k < 6; k++) {
    float gx = (k % 3 - 1) * f * 0.95, gy = (k / 3 - 0.5) * f * 1.05;
    if (twitching && twType[6] == k % 4) gx += random(-8, 8);
    tint(bright * (0.75 + 0.25 * noise(k, millis() * 0.001)), alpha);
    image(faces[k], gx, gy, f, f);
  }
  noTint();
  imageMode(CORNER);
  popMatrix();
}

void drawLockedPreview(String title, String hint) {
  float x = lineX(0), y = lineY(0);
  drawGroupFace(x, y, lineS(0), 20 * menuFlicker, 255);
  noFill();
  stroke(190, 185, 170);
  strokeWeight(14);
  arc(x, y - 18, 86, 100, PI, TWO_PI);
  noStroke();
  fill(190, 185, 170);
  rect(x - 66, y - 20, 132, 98, 6);
  fill(25);
  ellipse(x, y + 18, 22, 22);
  rect(x - 5, y + 18, 10, 34);
  previewLabel(title + "  [BLOQUEADO]", hint);
}

// RECUPERAÇÃO: all six in the dark, a flashlight beam drifting over them
void drawRecupPreview() {
  float x = lineX(0), y = lineY(0), s = lineS(0);
  float t = millis() / 1000.0;
  float bx = x + (noise(t * 0.35) - 0.5) * s * 1.1, by = y + (noise(t * 0.35 + 9) - 0.5) * s * 0.7;
  float f = s * 0.36;
  imageMode(CENTER);
  for (int k = 0; k < 6; k++) {
    float gx = x + (k % 3 - 1) * f * 0.95, gy = y + (k / 3 - 0.5) * f * 1.05;
    float lit = exp(-(sq(gx - bx) + sq(gy - by)) / sq(f * 0.75));
    boolean tw = millis() < twitchUntil[k];
    tint((8 + 235 * lit) * menuFlicker, 255);
    image(faces[k], gx + (tw ? twDx[k] * 0.4 : 0), gy + (tw ? twDy[k] * 0.4 : 0), f, f);
  }
  noTint();
  imageMode(CORNER);
  noStroke();
  for (int r = 6; r > 0; r--) {
    fill(255, 240, 210, 5);
    ellipse(bx, by, f * r * 0.35, f * r * 0.35);
  }
  previewLabel("RECUPERAÇÃO", "Todos eles. Nenhuma luz. Um certificado." + (dayBeaten[RECUP_DAY] ? "   ·   ✓" : ""));
}

// CATÁLOGO: three photo cards cycling through what you've discovered
void drawCataloguePreview() {
  float x = lineX(0), y = lineY(0) - 10;
  int now = millis();
  int cyc = now / 2600;
  float flick = constrain(1 - (now % 2600) / 140.0, 0, 1);
  ArrayList<Integer> met = new ArrayList<Integer>(), items = new ArrayList<Integer>(), msgs = new ArrayList<Integer>();
  for (int d = 0; d < DAYS; d++) if (dayKnown(d)) met.add(DAY_ORDER[d]);
  for (int k = 0; k < ITEM_NAMES.length; k++) if (itemSeen[k]) items.add(k);
  for (int k = 0; k < WALL_MSGS.length; k++) if (msgSeen[k]) msgs.add(k);
  catCard(x - 190, y + 24, -0.16, 0, met.isEmpty() ? -1 : met.get(cyc % met.size()), flick);
  catCard(x + 190, y + 24, 0.16, 2, items.isEmpty() ? -1 : items.get((cyc + 1) % items.size()), flick);
  catCard(x, y, 0.02, 1, msgs.isEmpty() ? -1 : msgs.get((cyc + 2) % msgs.size()), flick);
  previewLabel("CATÁLOGO", "NERDOLAS " + met.size() + "/" + DAYS + "   ·   PICHAÇÕES " + msgs.size() + "/" + WALL_MSGS.length
    + "   ·   ITENS " + items.size() + "/" + ITEM_NAMES.length);
}

void catCard(float cx, float cy, float rot, int kind, int idx, float flick) {
  float w = 240, h = 310;
  pushMatrix();
  translate(cx, cy);
  rotate(rot + sin(millis() * 0.0007 + kind) * 0.01);
  rectMode(CENTER);
  imageMode(CENTER);
  noStroke();
  fill(0, 120);
  rect(8, 10, w, h);
  fill(226, 220, 200);
  rect(0, 0, w, h);
  fill(40, 36, 30);
  rect(0, -20, w - 24, h - 80);
  String cap;
  if (kind == 0) {
    tint(idx >= 0 ? 225 : 14);
    image(faces[idx >= 0 ? idx : DAY_ORDER[0]], 0, -20, w - 34, w - 34);
    cap = idx >= 0 ? NAMES[idx].toUpperCase() : "???";
  } else if (kind == 1) {
    fill(170, 160, 95);
    rect(0, -20, w - 24, h - 80);
    if (idx >= 0) {
      tint(255);
      image(graffiti[idx], 0, -20, w - 30, (w - 30) * 0.5);
      cap = "PICHAÇÃO";
    } else {
      cap = "???";
    }
  } else {
    tint(idx >= 0 ? 255 : 20);
    image(itemTex[idx >= 0 ? idx : 0], 0, -20, 150, 150);
    cap = idx >= 0 ? ITEM_NAMES[idx].toUpperCase() : "???";
  }
  noTint();
  if (flick > 0) {
    tint(255, 200 * flick);
    image(staticImg, 0, -20, w - 24, h - 80);
    noTint();
  }
  rectMode(CORNER);
  imageMode(CORNER);
  fill(40);
  textFont(fontHud);
  textAlign(CENTER, CENTER);
  textSize(cap.length() > 16 ? 15 : 22);
  text(cap, 0, h / 2 - 32);
  popMatrix();
}

// CONQUISTAS: a big star filling with your completion + what's next
void drawAchPreview() {
  float x = lineX(0), y = lineY(0) - 50, r = 165;
  int got = achCountVisible(), tot = achTotalVisible();
  float frac = tot > 0 ? got / (float) tot : 0;
  noStroke();
  fill(255, 16);
  drawStar(x, y, r);
  imageMode(CORNER);
  if (frac > 0) {
    clip(x - r, y - r + (1 - frac) * 2 * r, 2 * r, 2 * r * frac + 1);
    fill(255, 205, 80, 225 * menuFlicker);
    drawStar(x, y, r);
    noClip();
  }
  noFill();
  stroke(255, 215, 90, 170);
  strokeWeight(3);
  drawStar(x, y, r);
  noStroke();
  textFont(fontHud);
  textAlign(CENTER, CENTER);
  textSize(46);
  fill(0, 140);
  text(got + " / " + tot, x + 2, y + 22);
  fill(245);
  text(got + " / " + tot, x, y + 20);

  textFont(fontUI);
  textSize(15);
  fill(170);
  float ly = y + r + 18;
  text(got == tot ? "TODAS DESBLOQUEADAS" : "PRÓXIMAS", x, ly);
  textFont(fontMail);
  textSize(15);
  int shown = 0;
  for (int k = 0; k < ACH_NAME.length && shown < 3; k++) {
    if (!achVisible(k) || achUnlocked[k]) continue;
    fill(215);
    text(ACH_NAME[k] + "  —  " + ACH_DESC[k], x, ly + 28 + shown * 24);
    shown++;
  }
}

// SAIR: the glowing door, and sometimes someone behind it
void drawExitPreview() {
  float x = lineX(0), y = lineY(0) - 10;
  int now = millis();
  float fl = random(1) < 0.06 ? random(0.3, 0.7) : 1;
  noStroke();
  for (int r = 8; r > 0; r--) {
    fill(40, 200, 90, 6 * fl);
    ellipse(x, y, r * 70, r * 90);
  }
  float ph = (now % 9000) / 9000.0;
  float peek = constrain(sin(constrain((ph - 0.7) / 0.3, 0, 1) * PI) * 1.4, 0, 1);
  imageMode(CENTER);
  if (peek > 0.01) {
    tint(150, 255 * peek * 0.8);
    image(faces[(now / 9000) % NAMES.length], x + 120 - 40 * peek, y - 40, 150, 150);
    noTint();
  }
  tint(255 * fl);
  image(exitTex, x, y, 256 * 0.85, 480 * 0.85);
  noTint();
  imageMode(CORNER);
}

void drawStatic() {
  if (millis() - lastStaticUpd > 50) {
    staticImg.loadPixels();
    for (int p = 0; p < staticImg.pixels.length; p++) staticImg.pixels[p] = color(random(255));
    staticImg.updatePixels();
    lastStaticUpd = millis();
  }
  imageMode(CORNER);
  tint(255, 16 + 160 * menuStatic);
  image(staticImg, 0, 0, width, height);
  noTint();
  noStroke();
  for (int k = 0; k < 3; k++) {
    float y = (millis() * (0.05 + k * 0.03) + k * 300) % height;
    fill(255, 10);
    rect(0, y, width, 2 + k);
  }
}

float optY(int i) { return 400 + i * 58; }

int hoveredOption() {
  for (int i = 0; i < MENU_OPTS.length; i++)
    if (mouseX > 60 && mouseX < 560 && abs(mouseY - optY(i)) < 26) return i;
  return -1;
}

void drawMainMenu() {
  float jx = random(1) < 0.03 ? random(-6, 6) : 0;
  textFont(fontBig);
  textAlign(LEFT, BASELINE);
  fill(235);
  textSize(72);
  text("BACKROOMS:", 80 + jx, 130);
  textSize(42);
  text("Escape from the", 84, 192);
  text("Nerdolas", 84, 240);

  // stars: 6 days, 7th = the week (e-mail), 8th (green) = 36h
  noStroke();
  int sx = 0;
  for (int k = 0; k < 8; k++) {
    boolean earned = k < 6 ? dayBeaten[k] : (k == 6 ? finalBeaten : recupUnlocked);
    if (!earned) continue;
    fill(k == 7 ? color(90, 220, 110) : color(255, 215, 90));
    drawStar(104 + sx * 46, 292, 18);
    sx++;
  }

  textFont(fontUI);
  textAlign(LEFT, CENTER);
  for (int i = 0; i < MENU_OPTS.length; i++) {
    boolean sel = i == menuSel;
    boolean locked = (i == 1 && !endlessUnlocked) || (i == 2 && !recupUnlocked);
    textSize(34);
    fill(locked ? (sel ? 150 : 70) : (sel ? 255 : 120));
    String label = (i == 2 && locked) ? "???" : MENU_OPTS[i];
    if (i == 4) label += "  (" + achCountVisible() + "/" + achTotalVisible() + ")";
    text((sel ? ">> " : "    ") + label, 84, optY(i));
  }

  String[] desc = {
    "Acumule certificados de horas e encontre a SAÍDA.",
    endlessUnlocked ? "Sobreviva o máximo que puder." : "Vença a semana da POLIWEEK para desbloquear.",
    recupUnlocked ? "Todos eles. Nenhuma luz. Um certificado." : "Valide 36h/36h na POLIWEEK para desbloquear.",
    "Nerdolas, pichações, itens e estatísticas.",
    "Veja suas conquistas.",
    "Fechar o jogo."
  };
  textSize(17);
  fill(170);
  text(desc[menuSel], 88, optY(MENU_OPTS.length) + 4);

  textSize(17);
  fill(190);
  String rec = "Horas acumuladas: " + hoursValidated() + "h/36h";
  if (endlessUnlocked) rec += "      Recorde ENDLESS: " + nf(best, 0, 1) + "s";
  text(rec, 84, height - 95);
  fill(140);
  text("↑↓ escolher   ←→ trocar   Enter jogar   Esc sair", 84, height - 60);
}

void drawAchievementsPage() {
  textFont(fontBig);
  textAlign(LEFT, BASELINE);
  fill(235);
  textSize(56);
  text("CONQUISTAS", 60, 100);
  textFont(fontUI);
  textSize(22);
  fill(255, 215, 90);
  text(achCountVisible() + " / " + achTotalVisible(), 450, 98);

  ArrayList<Integer> list = new ArrayList<Integer>();
  for (int k = 0; k < ACH_NAME.length; k++) if (achVisible(k)) list.add(k);
  rectMode(CORNER);
  int cols = 3;
  int perCol = max(1, (list.size() + cols - 1) / cols);
  float colW = 410, rowH = 68;
  for (int n = 0; n < list.size(); n++) {
    int k = list.get(n);
    int col = n / perCol, row = n % perCol;
    float x = 50 + col * (colW + 12), y = 125 + row * rowH;
    boolean on = achUnlocked[k];
    noStroke();
    fill(255, on ? 26 : 10);
    rect(x, y, colW, rowH - 6, 6);
    if (on) {
      fill(255, 215, 90);
      drawStar(x + 28, y + 31, 15);
    } else {
      noFill();
      stroke(120);
      strokeWeight(2);
      drawStar(x + 28, y + 31, 15);
      noStroke();
    }
    textAlign(LEFT, TOP);
    textSize(17);
    fill(on ? 255 : 150);
    text(ACH_NAME[k], x + 54, y + 7);
    textSize(12);
    fill(on ? 200 : 110);
    text(ACH_DESC[k], x + 54, y + 30, colW - 64, 32);
    textAlign(RIGHT, TOP);
    textSize(10);
    fill(ACH_MODE[k] == ENDLESS ? color(200, 160, 90) : color(110, 200, 130));
    text(ACH_MODE[k] == ENDLESS ? "ENDLESS" : "POLIWEEK", x + colW - 8, y + 9);
  }
  textAlign(CENTER, CENTER);
  textSize(18);
  fill(170);
  text("Esc, Enter ou clique para voltar", width / 2, height - 30);
}

// ---- CATÁLOGO
float tabX(int k) { return 60 + k * 250; }

void drawCatalogue() {
  textFont(fontBig);
  textAlign(LEFT, BASELINE);
  fill(235);
  textSize(56);
  text("CATÁLOGO", 60, 100);
  textFont(fontHud);
  textSize(22);
  textAlign(LEFT, CENTER);
  for (int k = 0; k < CAT_TABS.length; k++) {
    boolean sel = k == catTab;
    noStroke();
    fill(sel ? color(170, 20, 15) : color(0, 160));
    rect(tabX(k), 125, 235, 38);
    fill(sel ? 255 : 150);
    text(CAT_TABS[k], tabX(k) + 16, 144);
  }
  if (catTab == 0) drawCatNerdolas();
  else if (catTab == 1) drawCatMsgs();
  else if (catTab == 2) drawCatItems();
  else drawCatStats();
  textFont(fontUI);
  textAlign(CENTER, CENTER);
  textSize(16);
  fill(160);
  text("←→ trocar de aba    Esc voltar", width / 2, height - 30);
}

void drawCatNerdolas() {
  for (int d = 0; d < DAYS; d++) {
    int ch = DAY_ORDER[d];
    boolean met = dayKnown(d), beat = dayBeaten[d];
    float x = 60 + (d % 3) * 420, y = 185 + (d / 3) * 330;
    hudSlab(x, y, 400, 310);
    fill(beat ? color(170, 20, 15) : color(60));
    rect(x, y, 7, 310);
    imageMode(CORNER);
    tint(met ? 230 : 18);
    image(faces[ch], x + 22, y + 20, 130, 130);
    noTint();
    textFont(fontHud);
    textAlign(LEFT, TOP);
    textSize(26);
    fill(met ? 240 : 90);
    text(met ? NAMES[ch].toUpperCase() : "???", x + 170, y + 22);
    textFont(fontUI);
    textSize(16);
    fill(met ? color(220, 70, 50) : color(80));
    text(met ? NICKS[ch] : "???", x + 170, y + 58);
    fill(140);
    textSize(13);
    text("DIA " + (d + 1) + (beat ? "   ·   ✓ " + dayCerts[d] * HOURS_PER_CERT + "h" : ""), x + 170, y + 86);
    textFont(fontMail);
    textSize(15);
    fill(beat ? 225 : 110);
    String desc = beat ? TRAITS[ch] : (met ? "??? — vença o Dia " + (d + 1) + " da POLIWEEK para descobrir como ele age." : "???");
    text(desc, x + 22, y + 165, 360, 135);
  }
}

void drawCatMsgs() {
  for (int k = 0; k < WALL_MSGS.length; k++) {
    float y = 190 + k * 120;
    hudSlab(60, y, 1240, 100);
    fill(msgSeen[k] ? color(150, 15, 12) : color(60));
    rect(60, y, 7, 100);
    textAlign(LEFT, CENTER);
    if (msgSeen[k]) {
      textFont(fontGraffiti);
      textSize(34);
      fill(170, 25, 20);
      text(WALL_MSGS[k].replace('\n', ' '), 90, y + 50);
    } else {
      textFont(fontHud);
      textSize(30);
      fill(80);
      text("???  —  ainda não encontrada", 90, y + 50);
    }
  }
}

void drawCatItems() {
  imageMode(CORNER);
  for (int k = 0; k < ITEM_NAMES.length; k++) {
    float y = 175 + k * 96;
    hudSlab(60, y, 1240, 86);
    tint(itemSeen[k] ? 255 : 25);
    image(itemTex[k], 80, y + 7, 72, 72);
    noTint();
    textAlign(LEFT, TOP);
    textFont(fontHud);
    textSize(24);
    fill(itemSeen[k] ? 240 : 90);
    text(itemSeen[k] ? ITEM_NAMES[k].toUpperCase() : "???", 180, y + 12);
    textFont(fontMail);
    textSize(16);
    fill(itemSeen[k] ? 200 : 100);
    text(itemSeen[k] ? ITEM_DESC[k] + "   [" + ITEM_KEYS[k] + "]" : "Pegue esse item para descobrir o que ele faz.", 180, y + 50);
  }
}

void drawCatStats() {
  String[] labels = {
    "Partidas", "Mortes", "Fugas pela SAÍDA", "Tempo total nos Backrooms", "Itens coletados", "Itens consumidos",
    "Atordoamentos", "Perseguições escapadas", "Certificados coletados", "Horas acumuladas", "Dias vencidos", "Recorde ENDLESS",
    "Pizzas do Papponi"
  };
  int pizzas = 0;
  for (boolean b : pizzaGot) if (b) pizzas++;
  int days = 0;
  for (int d = 0; d <= FINAL_DAY; d++) if (dayBeaten[d]) days++;
  String[] values = {
    str(totalRuns), str(totalDeaths), str(totalWins), fmtTime(totalTime), str(totalItems), str(totalConsumed),
    str(totalStuns), str(totalEscapes), str(totalCerts), hoursValidated() + "h/36h", days + "/7",
    endlessUnlocked ? nf(best, 0, 1) + "s" : "BLOQUEADO",
    pizzas + "/" + PHASES + (pizzas > 0 ? "   (+" + round(PIZZA_BONUS * 100 * pizzas) + "% FÔLEGO)" : "")
  };
  for (int k = 0; k < labels.length; k++) {
    float x = 60 + (k % 2) * 630, y = 190 + (k / 2) * 92;
    hudSlab(x, y, 610, 84);
    fill(170, 20, 15);
    rect(x, y, 7, 84);
    textAlign(LEFT, CENTER);
    textFont(fontMono);
    textSize(15);
    fill(150);
    text(labels[k].toUpperCase(), x + 24, y + 26);
    textFont(fontHud);
    textSize(32);
    fill(235, 230, 215);
    text(values[k], x + 24, y + 58);
  }
}

void activateMenu(int i) {
  menuStatic = 0.2;
  if (i == 0) {
    lineupMode = FUGA;
    startRun(FUGA, lineSel());
  } else if (i == 1) {
    if (!endlessUnlocked) {
      menuStatic = 0.35;
      return;
    }
    lineupMode = ENDLESS;
    startRun(ENDLESS, lineSel());
  } else if (i == 2) {
    if (!recupUnlocked) {
      menuStatic = 0.35;
      return;
    }
    startRun(FUGA, RECUP_DAY);
  } else if (i == 3) {
    menuPageTo(2);
  } else if (i == 4) {
    menuPageTo(1);
  } else {
    exit();
  }
}

void cycleLineup(int dir) {
  if (!previewIsLineup()) return;
  int n = lineupChars().length;
  if (n <= 1) return;
  setLineSel((lineSel() + dir + n) % n);
  lineShift += dir;
  menuStatic = max(menuStatic, 0.12);
}

// =====================================================================
// PAUSE MENU + SOUND SETTINGS
void pauseGame() {
  if (state != PLAYING || paused) return;
  paused = true;
  pauseStart = millis();
  pausePage = 0;
  pauseSel = 0;
  pauseShot = null;
  releaseKeys();
  peekSide = 0;
  lockMouse(false);
  silenceSynth();
  pauseVoices();
}

void resumeGame() {
  if (!paused) return;
  paused = false;
  shiftClock(millis() - pauseStart);
  lastMs = millis();
  releaseKeys();
  lockMouse(true);
  for (Enemy e : enemies) voices[e.ch].loop();
  saveSettings();
}

// everything in the run is timed against millis(): push it all forward by the time spent paused
void shiftClock(int d) {
  startMs += d;
  msgUntil += d;
  blinkUntil += d;
  nextBlink += d;
  useStart += d;
  energyUntil += d;
  swiftUntil += d;
  ghostUntil += d;
  fedUntil += d;
  pilhadoUntil += d;
  fireUntil += d;
  flickerUntil += d;
  lastThrow += d;
  lastStingMs += d;
  toastStart += d;
  for (int k = 0; k < pickupTimes.size(); k++) pickupTimes.set(k, pickupTimes.get(k) + d);
  for (Enemy e : enemies) {
    e.lockUntil += d;
    e.lungeUntil += d;
    e.screamUntil += d;
    e.stunUntil += d;
    e.confusedUntil += d;
    e.nextTeleport += d;
  }
  for (Can c : cans) {
    c.lastClank += d;
    c.lastAlert += d;
  }
}

void pauseAction(int i) {
  if (pausePage == 1) {
    if (i == VOL_NAMES.length) {
      saveSettings();
      pausePage = 0;
      pauseSel = 1;
    }
    return;
  }
  if (i == 0) {
    resumeGame();
  } else if (i == 1) {
    pausePage = 1;
    pauseSel = 0;
  } else if (i == 2) {
    paused = false;
    saveSettings();
    endRun(false);
    startRun(gameMode, runEntry);
  } else if (i == 3) {
    paused = false;
    saveSettings();
    goMenu();
  }
}

void pauseKey(int kc) {
  int n = pausePage == 0 ? PAUSE_OPTS.length : VOL_NAMES.length + 1;
  if (kc == ESC || kc == BACKSPACE || (kc == 'P' && pausePage == 0)) {
    if (pausePage == 1) pauseAction(VOL_NAMES.length);
    else resumeGame();
  } else if (kc == UP || kc == 'W') {
    pauseSel = (pauseSel + n - 1) % n;
  } else if (kc == DOWN || kc == 'S') {
    pauseSel = (pauseSel + 1) % n;
  } else if (pausePage == 1 && pauseSel < VOL_NAMES.length && (kc == LEFT || kc == 'A' || kc == RIGHT || kc == 'D')) {
    setVol(pauseSel, vol[pauseSel] + (kc == LEFT || kc == 'A' ? -10 : 10));
  } else if (kc == ENTER || kc == RETURN || kc == ' ') {
    pauseAction(pauseSel);
  }
}

float pauseOptY(int i) { return 270 + i * 62; }
final float VOL_BAR_X = 380, VOL_BAR_W = 420;

int pauseHovered() {
  int n = pausePage == 0 ? PAUSE_OPTS.length : VOL_NAMES.length + 1;
  float right = pausePage == 0 ? 560 : VOL_BAR_X + VOL_BAR_W + 100;
  for (int i = 0; i < n; i++)
    if (mouseX > 60 && mouseX < right && abs(mouseY - pauseOptY(i)) < 26) return i;
  return -1;
}

void pauseMouse(boolean click) {
  int h = pauseHovered();
  if (h < 0) return;
  pauseSel = h;
  if (pausePage == 1 && h < VOL_NAMES.length && mouseX >= VOL_BAR_X - 10 && mouseX <= VOL_BAR_X + VOL_BAR_W + 10) {
    if (click || mousePressed) setVol(h, round(constrain((mouseX - VOL_BAR_X) / VOL_BAR_W, 0, 1) * 20) * 5);
  } else if (click) {
    pauseAction(h);
  }
}

void drawPause() {
  if (pauseShot == null) {                    // freeze the last frame as the backdrop
    render();
    pauseShot = get();
  }
  background(0);
  begin2D();
  imageMode(CORNER);
  tint(110);
  image(pauseShot, 0, 0, width, height);
  noTint();
  noStroke();
  fill(0, 185);
  rect(0, 0, width, height);

  textFont(fontBig);
  textAlign(LEFT, BASELINE);
  fill(235);
  textSize(72);
  text(pausePage == 0 ? "PAUSADO" : "SOM", 80, 170);

  textFont(fontUI);
  textAlign(LEFT, CENTER);
  if (pausePage == 0) {
    for (int i = 0; i < PAUSE_OPTS.length; i++) {
      boolean sel = i == pauseSel;
      textSize(34);
      fill(sel ? 255 : 120);
      text((sel ? ">> " : "    ") + PAUSE_OPTS[i], 84, pauseOptY(i));
    }
    String[] desc = {"Voltar para os Backrooms.", "Volume geral, ambiente, efeitos e vozes.",
      "Começar esta partida de novo.", "Abandonar a partida."};
    textSize(17);
    fill(170);
    text(desc[pauseSel], 88, pauseOptY(PAUSE_OPTS.length) + 4);
  } else {
    for (int i = 0; i <= VOL_NAMES.length; i++) {
      boolean sel = i == pauseSel;
      float y = pauseOptY(i);
      textSize(34);
      fill(sel ? 255 : 120);
      text((sel ? ">> " : "    ") + (i < VOL_NAMES.length ? VOL_NAMES[i] : "VOLTAR"), 84, y);
      if (i == VOL_NAMES.length) continue;
      float v = vol[i] / 100.0;
      fill(255, 30);
      rect(VOL_BAR_X, y - 5, VOL_BAR_W, 10);
      fill(sel ? color(225, 215, 180) : color(150, 145, 125));
      rect(VOL_BAR_X, y - 5, VOL_BAR_W * v, 10);
      rect(VOL_BAR_X + VOL_BAR_W * v - 5, y - 14, 10, 28);
      textSize(22);
      fill(sel ? 235 : 140);
      text(vol[i] + "%", VOL_BAR_X + VOL_BAR_W + 26, y);
    }
  }

  textSize(17);
  fill(140);
  text(pausePage == 0 ? "↑↓ escolher   Enter confirmar   Esc continuar"
    : "↑↓ escolher   ←→ ajustar (ou arraste)   Esc voltar", 84, height - 60);
  end2D();
}

// ---- volumes: percent per channel, the master scales the other three
float volDb(int ch) {
  float p = vol[ch] / 100.0 * (ch == V_MASTER ? 1 : vol[V_MASTER] / 100.0);
  if (p <= 0.001) return -80;
  return 20 * (float) Math.log10(p);
}

void setVol(int ch, int v) {
  v = constrain(v, 0, 100);
  if (v == vol[ch]) return;
  vol[ch] = v;
  applyVolumes();
  if ((ch == V_MASTER || ch == V_FX) && clanks != null) {   // a clank so you hear the new level
    setVoice(clanks[0], -12 + volDb(V_FX), 0);
    clanks[0].trigger();
  }
}

void setGainDb(Controller c, float db) {
  if (c != null && c.hasControl(Controller.GAIN)) c.setGain(max(db, -80));
}

// the synth (out), the ambience and the flashlight click; voices and clanks add their offset when played
void applyVolumes() {
  setGainDb(ambience, volDb(V_AMB));
  setGainDb(out, volDb(V_FX));
  setGainDb(flashSnd, -4 + volDb(V_FX));
}

void loadSettings() {
  if (!new File(sketchPath("settings.txt")).exists()) return;
  for (String line : loadStrings("settings.txt")) {
    String[] kv = split(line.trim(), '=');
    if (kv.length < 2 || !kv[0].equals("vol")) continue;
    String[] p = split(kv[1], ',');
    for (int k = 0; k < min(p.length, vol.length); k++) vol[k] = constrain(int(p[k].trim()), 0, 100);
  }
}

void saveSettings() {
  saveStrings(sketchPath("settings.txt"), new String[]{"vol=" + join(nf(vol, 0), ",")});
}

// =====================================================================
// INPUT
void lockMouse(boolean on) {
  win.confinePointer(on);
  win.setPointerVisible(!on);
  if (on) {
    win.warpPointer(width / 2, height / 2);
    skipMouse = 2;
  }
}

void mouseMoved() {
  if (state == MENU && menuPage == 0) {
    int h = hoveredOption();
    if (h >= 0) menuSelect(h);
  }
  if (state == PLAYING && paused) pauseMouse(false);
  look();
}

void mouseDragged() {
  if (state == PLAYING && paused) pauseMouse(false);
  look();
}

void look() {
  if (state != PLAYING || paused) return;
  if (skipMouse > 0) {
    skipMouse--;
    return;
  }
  float dx = mouseX - width / 2, dy = mouseY - height / 2;
  if (dx == 0 && dy == 0) return;
  yaw += dx * MOUSE_SENS;
  pitch = constrain(pitch - dy * MOUSE_SENS, -1.2, 1.2);
  win.warpPointer(width / 2, height / 2);
}

void mousePressed() {
  if (state == MENU) {
    if (menuPage == 1) {
      menuPageTo(0);
      return;
    }
    if (menuPage == 2) {
      for (int k = 0; k < CAT_TABS.length; k++) {
        if (mouseX > tabX(k) && mouseX < tabX(k) + 235 && mouseY > 125 && mouseY < 163 && k != catTab) {
          catTab = k;
          pageStatic();
        }
      }
      return;
    }
    int h = hoveredOption();
    if (h >= 0) {
      activateMenu(h);
      return;
    }
    if (!previewIsLineup()) return;
    int[] chars = lineupChars();
    int n = chars.length, sel = lineSel();
    for (int i = 0; i < n; i++) {
      float p = i + lineShift, s = lineS(p);
      if (abs(mouseX - lineX(p)) < s / 2 && abs(mouseY - lineY(p)) < s / 2) {
        if (i > 0) {
          setLineSel((sel + i) % n);
          lineShift += i;
          menuStatic = max(menuStatic, 0.12);
        }
        break;
      }
    }
  } else if (state == PLAYING && paused) {
    pauseMouse(true);
  } else if (state == PLAYING && mouseButton == LEFT) {
    fireTaser();
  }
}

void keyPressed() {
  if (key == ESC) {
    key = 0;
    if (state == MENU) {
      if (menuPage != 0) menuPageTo(0);
      else exit();
    } else if (state == PLAYING) {
      if (paused) pauseKey(ESC);
      else pauseGame();
    } else {
      goMenu();
    }
    return;
  }
  int kc = keyCode;
  boolean inRange = kc >= 0 && kc < keyDown.length;
  boolean fresh = inRange && !keyDown[kc];
  if (inRange) keyDown[kc] = true;
  setMove(kc, true);
  if (!fresh) return;

  boolean enter = kc == ENTER || kc == RETURN;
  if (state == MENU) {
    menuKey(kc);
    return;
  }
  if (state == PLAYING && paused) {
    pauseKey(kc);
    return;
  }
  if (state == PLAYING) {
    if (kc == 'F') {
      flashlightOn = !flashlightOn;
      flashClick();
    }
    if (kc == 'C') crouchToggle = !crouchToggle;
    if (kc == 'P') pauseGame();
    if (kc >= '1' && kc <= '4') startUse(kc - '1');
    if (kc == '5') startUse(MONSTER);
    if (kc == 'G') throwCan();
    if (kc == 'Q' && !startPeek(-1)) fireTaser();             // at a left corner Q peeks, elsewhere it's the taser
    if (kc == 'E') {
      if (gameMode == FUGA && nearCert >= 0) collectCert();     // a certificate in reach wins over peeking
      else startPeek(1);
    }
  }
  if (state == DEAD && millis() - deathMs > 1000) {
    if (kc == 'R') startRun(gameMode, runEntry);
    if (kc == 'M') goMenu();
  }
  if (state == WIN && millis() - winMs > 1000) {
    if (emailPending) {
      if (enter) openEmail();
    } else {
      if (kc == 'R') startRun(gameMode, runEntry);
      if (kc == 'M') goMenu();
    }
  }
  if (state == EMAIL && enter && millis() - emailMs > 2500) goMenu();
}

void menuKey(int kc) {
  boolean enter = kc == ENTER || kc == RETURN || kc == ' ';
  if (menuPage == 1) {
    if (enter || kc == BACKSPACE) menuPageTo(0);
    return;
  }
  if (menuPage == 2) {
    if (kc == LEFT || kc == 'A') {
      catTab = (catTab + CAT_TABS.length - 1) % CAT_TABS.length;
      pageStatic();
    } else if (kc == RIGHT || kc == 'D') {
      catTab = (catTab + 1) % CAT_TABS.length;
      pageStatic();
    } else if (enter || kc == BACKSPACE) {
      menuPageTo(0);
    }
    return;
  }
  int n = MENU_OPTS.length;
  if (kc == UP || kc == 'W') {
    menuSelect((menuSel + n - 1) % n);
  } else if (kc == DOWN || kc == 'S') {
    menuSelect((menuSel + 1) % n);
  } else if (kc == LEFT || kc == 'A') {
    cycleLineup(-1);
  } else if (kc == RIGHT || kc == 'D') {
    cycleLineup(1);
  } else if (enter) {
    activateMenu(menuSel);
  }
}

void keyReleased() {
  int kc = keyCode;
  if (kc >= 0 && kc < keyDown.length) keyDown[kc] = false;
  setMove(kc, false);
}

void setMove(int kc, boolean v) {
  if (kc == UP || kc == 'W') kUp = v;
  else if (kc == DOWN || kc == 'S') kDown = v;
  else if (kc == LEFT || kc == 'A') kLeft = v;
  else if (kc == RIGHT || kc == 'D') kRight = v;
  else if (kc == SHIFT) kSprint = v;
  else if (kc == CONTROL) kCrouch = v;
}

void releaseKeys() {
  java.util.Arrays.fill(keyDown, false);
  kUp = kDown = kLeft = kRight = kSprint = kCrouch = false;
}