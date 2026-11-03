// BACKROOMS: Escape from the Nerdolas — v1.2
// Processing 4 (P3D) + Minim. Assets: carpet.jpg wall.jpg roof.jpg menu.png ambiente.mp3
//   gabriel / vitor / gustavo / isa / gaias / luca (.jpg + .mp3)
//   optional: data/pucpr.png (any photo of the PUCPR campus, blurred automatically)
//   optional: data/flashlight.mp3
// Save files: best.txt, best_fuga.txt, achievements.txt, progress.txt

import ddf.minim.*;
import ddf.minim.ugens.*;
import ddf.minim.spi.*;
import com.jogamp.newt.opengl.GLWindow;

// ---------------- tuning knobs ----------------
int GRID = 25;                     // floor sampling grid (odd) — changes per mode
final int MAX_GRID     = 37;
final int GRID_ENDLESS = 25, GRID_DAY = 31, GRID_FINAL = 37;
final float CELL         = 400;    // size of one cell in world units
final float WALL_H       = 300;    // ceiling height
final float EYE_H        = 165;    // camera height
final float PLAYER_R     = 60;     // player collision radius
final float WALK_SPEED   = 260;    // units per second
final float SPRINT_SPEED = 440;
final float STAMINA_MAX  = 2.5;    // seconds of sprint
final float ENEMY_START  = 190;
final float ENEMY_MAX    = 400;
final float ENEMY_RAMP   = 1.4;    // enemy speed gained per second survived
final float GRACE_TIME   = 3;      // seconds before the enemies start hunting
final float KILL_DIST    = 110;
final float MOUSE_SENS   = 0.0025;

// ---------------- visuals ----------------
final float FOG_DIST      = 99999; // so basically no fog
final float EXPOSURE_BASE = 0.72;
final float BASE_FOV = 50;
final boolean VOLUMETRIC  = true;
final boolean SHOW_WET_MASK = false; // true: highlight the procedural wet patches in cyan
final float VHS_AMOUNT    = 0.15;
final float HANDHELD      = 0.5;
final int   OUTLETS       = 26;    // wall props (scaled with map size)
final int   VENTS         = 12;
final float LENS_FISHEYE  = 0.2;   // the player's vision (world + hands): barrel distortion
final float LENS_GRAIN    = 0.005; // film grain on the player's vision (very subtle)
final float LENS_SOFT     = 0.3;   // grainy micro-blur, a bit softer toward the edges (very subtle)
final float OSD_FISHEYE   = 0.04;  // the whole camcorder image, on-screen text included
final int   MAP_FLOATS    = (MAX_GRID * MAX_GRID + 3) / 4;   // 4 cells packed per float
final int   MAP_VEC4      = (MAP_FLOATS + 3) / 4;
final float[] PACK        = {1, 17, 289, 4913};             // base-17 packing for the shader grid

// ---------------- player ----------------
final float CROUCH_SPEED = 150;
final float CROUCH_EYE   = 105;
final float PEEK_ANGLE   = 0.23;   // how far the torso tilts when leaning (radians, ~13 deg)
final float PEEK_PIVOT   = 0.45;   // the lean pivots at the hips: this fraction of the eye height
final float PEEK_MIN     = 20;     // less room than this beside you = no lean
final float PEEK_HEAD_R  = 30;     // the head's clearance from walls while leaning
final float PEEK_WALL    = 220;    // the wall in front must be this close to count as a corner
final float PEEK_VIEW_GAIN = 250;  // leaning must open the view at least this much further
final float PEEK_ROLL    = radians(16);   // head tilt at full lean (the view rolls 0 -> 16 deg)

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
final String[] ITEM_KEYS   = {"1", "2", "3", "4", "R", "5", "G"};
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
final int   SECRETS     = 3;          // maximum optional passages; only naturally dark wall faces qualify
final int   SECRET_NEAR = 14;         // prefer marked panels within this walking distance of the start
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
final float SIGHT_FLASH  = 14;     // maximum when lit; camera light also checks its short reach
final float SIGHT_DARK   = 0.2;    // in pitch dark, sight shrinks to 20% (2 rooms; crouched and still: under 1)
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
Gain fxBus, voiceBus;
Summer fxMix, voiceMix;
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

// ---------------- 3D audio ----------------
Delay stepEcho;                     // room echo on your footsteps
Multiplier echoWet;
float roomOpen;                     // 0 = tight corridor, 1 = big open hall
MoogFilter distLP;                  // distant one-shot events
Pan distPan;
Multiplier distNAmp;
Oscil distO;
int distType = -1;
float distT, distVol, nextDistant = 12;

// a looping voice: muffled by walls in the way, panned by direction
class Voice3D {
  FilePlayer fp;
  TickRate rate;                         // fixed: corrects the file's sample rate to the output's
  MoogFilter lp = new MoogFilter(12000, 0);
  Gain gain = new Gain(-80);
  Pan pan = new Pan(0);                  // mono in, equal-power stereo out
  float g = -80, p = 0, c = 12000;
  Voice3D(String file) {
    AudioRecordingStream st = minim.loadFileStream(file);
    float fileRate = st.getFormat().getSampleRate();
    fp = new FilePlayer(st);
    rate = new TickRate(fileRate / out.sampleRate());
    rate.setInterpolation(true);
    fp.patch(rate).patch(lp).patch(gain).patch(pan).patch(voiceMix);
    println(file + ": " + fileRate + " Hz, " + st.getFormat().getChannels() + " ch  ->  output " + out.sampleRate() + " Hz");
  }
  void set(float tg, float tp, float tc, float dt) {
    float k = 1 - exp(-dt * 9);
    g = lerp(g, tg, k);
    p = lerp(p, tp, k);
    c = lerp(c, tc, k);
    apply();
  }
  void snap(float tg, float tp, float tc) {
    g = tg;
    p = tp;
    c = tc;
    apply();
  }
  void apply() {
    gain.setValue(g);
    pan.setPan(constrain(p, -1, 1));
    lp.frequency.setLastValue(constrain(c, 80, 12000));
  }
  void play()   { fp.play(); }
  void loop()   { fp.loop(); }
  void pause()  { fp.pause(); }
  void rewind() { fp.rewind(); }
  boolean isPlaying() { return fp.isPlaying(); }
}

// a nerdola's footsteps, positioned in 3D
class Steps3D {
  MoogFilter lp = new MoogFilter(420, 0.35);
  Multiplier amp = new Multiplier(0);
  Pan pan = new Pan(0);
  float env, phase;
  Steps3D() {
    new Noise(1, Noise.Tint.BROWN).patch(lp).patch(amp).patch(pan).patch(fxMix);
  }
}

Voice3D[] voices = new Voice3D[NAMES.length];
Steps3D[] eSteps = new Steps3D[6];

// ---------------- graphics ----------------
PImage carpet, wall, roof, menuImg, panelTex, certTex, exitTex, staticImg, outletTex, ventTex, pucprBg;
PImage[] itemTex = new PImage[ITEM_NAMES.length];
PImage[] graffiti = new PImage[WALL_MSGS.length];
PShape level;
PShader world, post, lens, tape;
GLWindow win;
PFont fontBig, fontUI, fontMono, fontGraffiti, fontHud, fontMail;
float exposureAdapt = 1, camGain = 0;
float camX, camY, camZ, camDX, camDY, camDZ;

boolean[][] solid;
// One wall system: 100 world units = 1 metre; CELL = 4 metres.
// Boundary solid cells represent exterior void, never interior wall blocks.
final float WALL_THICKNESS = 100;
final int WALL_SUBDIV = 8;
boolean[][] wallVoxels;
boolean[][] wallX, wallY;
final int WALL_FLOATS = (MAX_GRID * MAX_GRID + 7) / 8;
final int WALL_VEC4 = (WALL_FLOATS + 3) / 4;
float[] wallU = new float[WALL_VEC4 * 4];
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

// A marked wall panel opens a shortcut when illuminated.
class Secret {
  int di, dj;          // the near floor cell
  int wi, wj;          // the floor cell across the opening panel
  float light;         // how long it's been in your beam
  boolean opened, pizza, eaten;
  Decal mark;          // Cabral's sun uses ordinary wall-paint lighting in an unlit spawn area.
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
  int[][] goalFlow, navFlow;
  ArrayList<PVector> navRoute = new ArrayList<PVector>();
  int navIndex;
  int goalI = -1, goalJ = -1;
  float sx, sy;
  float unseenFor;        // Luca: how long you haven't been looking at him
  float lastVX, lastVY;   // your velocity at the moment it last detected you
  boolean inFront;
  float face = random(TWO_PI);   // where it's looking
  float scanBase, scanT;         // looking around while it stands still
  boolean wasMoving;
  float speedNow;
  int corners;
  float apX, apY;
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

// dynamic inventory HUD
float[] slotShow = new float[ITEM_NAMES.length], slotX = new float[ITEM_NAMES.length], slotPop = new float[ITEM_NAMES.length];
int[] lastInv = new int[ITEM_NAMES.length];

ArrayList<Integer> slotOrder = new ArrayList<Integer>();   // consumables, in the order you picked them up
String[] slotKey = {"", "", "", "", "R", "", "G"};                   // label each slot was last drawn with

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
final float EYE_SCALE = 0.8;                  // slightly smaller than before
final int[] EYE_RANK = {0, 5, 4, 3, 2, 1};    // none, hunting, chase, stunned, confused, search

class Eye {
  float opening, lx, ly, x = -1, sc = EYE_SCALE, show, seed = random(100);
  int blinkUntil, nextBlink, twUntil;
  float twx, twy, twr;
}
Eye mainEye = new Eye();
Eye[] packEyes = new Eye[6];

float yaw, pitch, stamina, bobPhase;
float eyeH = EYE_H;
float fov = radians(BASE_FOV), roll;
boolean moving, sprinting, crouching, crouchToggle, exhausted, flashlightOn = true;
int peekSide, peekDir;               // -1 left (Q), 1 right (E), 0 not peeking; peekDir = last side, for the ease-out
float peekAmt;                       // 0..1 how far the head is leaned out
PVector peekOff = new PVector();     // where the eye goes, relative to the body
PVector peekL, peekR;                // corners you could lean around right now (null = none)
float flicker = 1, flickerUntil = 0;
float stepEnv, hbPhase, breathPhase, staticBurst;
float frameDt;

// ---------------- camera-mounted light ----------------
// 100 world units = 1 m. Compact neutral-white flashlight with a focused beam.
final float FLASH_POWER = 1.55;
final float FLASH_RANGE = 900;       // fades to zero at 9 m
final float FLASH_FALLOFF = 260;     // half-strength distance, 2.6 m
final float FLASH_INNER_COS = 0.985, FLASH_OUTER_COS = 0.866; // 10° core, 30° soft edge
final PVector FLASH_COLOR = new PVector(1.0, 0.97, 0.92);
PVector flashPos = new PVector(), flashDir = new PVector(1, 0, 0);
float cameraRoll = 0, cameraRightX = 0, cameraRightY = 1; // shared camera pose

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
  "uniform vec4 wallData[" + WALL_VEC4 + "];",
  "uniform float gridSize;",
  "uniform float cellSize;",
  "uniform float wallH;",
  "uniform float wallHalf;",
  "uniform float lampZ;",
  "uniform float flash;",
  "uniform vec3 flashPos;",
  "uniform vec3 flashDir;",
  "uniform vec3 flashCol;",
  "uniform float flashRange;",
  "uniform float flashFalloff;",
  "uniform vec2 flashCone;",
  "uniform float emissive;",
  "uniform float wallpaper;",
  "uniform float wetDebug;",
  "uniform float exposure;",
  "uniform sampler2D giMap;",
  "uniform sampler2D wallGIMap;",
  "uniform sampler2D giDynamic;",
  "uniform float giSize;",
  "uniform float giWallSize;",
  "uniform float fogDist;",
  "uniform float volOn;",
  "uniform vec3 fogColor;",
  "varying vec4 vertColor;",
  "varying vec4 vertTexCoord;",
  "varying vec3 wPos;",
  "varying vec3 ePos;",
  "const float PI = 3.14159265;",
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
  "float wallCode(vec2 c) {",
  "  if (c.x < 0.0 || c.y < 0.0 || c.x >= gridSize || c.y >= gridSize) return 0.0;",
  "  float idx = c.y * gridSize + c.x;",
  "  float fi = floor(idx / 8.0); float sub = mod(idx, 8.0);",
  "  vec4 v = wallData[int(floor(fi / 4.0))]; float r = mod(fi, 4.0);",
  "  float packed = r < 0.5 ? v.x : (r < 1.5 ? v.y : (r < 2.5 ? v.z : v.w));",
  "  return mod(floor((packed + 0.01) / pow(4.0, sub)), 4.0);",
  "}",
  "// Same square-capped 1 m wall volumes as CPU collision and the welded mesh.",
  "float wallXAt(vec2 edge) { return mod(wallCode(edge - vec2(1.0, 0.0)), 2.0); }",
  "float wallYAt(vec2 edge) { return floor(wallCode(edge - vec2(0.0, 1.0)) / 2.0); }",
  "",
  "float wallBoxHit(vec3 a, vec3 b, vec2 lo, vec2 hi) {",
  "  vec3 delta = b - a;",
  "  vec3 safe = vec3(abs(delta.x) < 0.000001 ? 0.000001 : delta.x,",
  "                   abs(delta.y) < 0.000001 ? 0.000001 : delta.y,",
  "                   abs(delta.z) < 0.000001 ? 0.000001 : delta.z);",
  "  vec3 t0 = (vec3(lo, 0.0) - a) / safe;",
  "  vec3 t1 = (vec3(hi, wallH) - a) / safe;",
  "  vec3 nearT = min(t0, t1), farT = max(t0, t1);",
  "  float enter = max(0.0, max(nearT.x, max(nearT.y, nearT.z)));",
  "  float leave = min(1.0, min(farT.x, min(farT.y, farT.z)));",
  "  return enter <= leave + 0.0000001 ? 1.0 : 0.0;",
  "}",
  "",
  "float wallsInCell(vec2 cell, vec3 a, vec3 b) {",
  "  vec2 halfSize = vec2(wallHalf);",
  "  for (int side = 0; side < 2; side++) {",
  "    for (int along = -1; along <= 1; along++) {",
  "      vec2 edge = cell + vec2(float(side), float(along));",
  "      if (wallXAt(edge) > 0.5) {",
  "        vec2 lo = edge * cellSize - halfSize;",
  "        vec2 hi = (edge + vec2(0.0, 1.0)) * cellSize + halfSize;",
  "        if (wallBoxHit(a, b, lo, hi) > 0.5) return 1.0;",
  "      }",
  "      edge = cell + vec2(float(along), float(side));",
  "      if (wallYAt(edge) > 0.5) {",
  "        vec2 lo = edge * cellSize - halfSize;",
  "        vec2 hi = (edge + vec2(1.0, 0.0)) * cellSize + halfSize;",
  "        if (wallBoxHit(a, b, lo, hi) > 0.5) return 1.0;",
  "      }",
  "    }",
  "  }",
  "  return 0.0;",
  "}",
  "",
  "float wallVisibility(vec3 a, vec3 b) {",
  "  vec2 cell = floor(a.xy / cellSize), endCell = floor(b.xy / cellSize);",
  "  vec2 delta = b.xy - a.xy, direction = sign(delta);",
  "  vec2 safe = vec2(abs(delta.x) < 0.000001 ? 0.000001 : delta.x,",
  "                   abs(delta.y) < 0.000001 ? 0.000001 : delta.y);",
  "  vec2 nextEdge = (cell + max(direction, vec2(0.0))) * cellSize;",
  "  vec2 nextT = (nextEdge - a.xy) / safe;",
  "  vec2 stride = abs(vec2(cellSize) / safe);",
  "  if (direction.x == 0.0) nextT.x = 1.0e20;",
  "  if (direction.y == 0.0) nextT.y = 1.0e20;",
  "  for (int walk = 0; walk < 32; walk++) {",
  "    if (wallsInCell(cell, a, b) > 0.5) return 0.0;",
  "    if (all(lessThan(abs(cell - endCell), vec2(0.5)))) return 1.0;",
  "    if (abs(nextT.x - nextT.y) < 0.000001) { cell += direction; nextT += stride; }",
  "    else if (nextT.x < nextT.y) { cell.x += direction.x; nextT.x += stride.x; }",
  "    else { cell.y += direction.y; nextT.y += stride.y; }",
  "  }",
  "  return 0.0;",
  "}",
  "",
  "float wallBoxDistance(vec2 p, vec2 lo, vec2 hi) {",
  "  return length(max(max(lo - p, p - hi), vec2(0.0)));",
  "}",
  "",
  "float nearestWall(vec2 p) {",
  "  vec2 cell = floor(p / cellSize), h = vec2(wallHalf);",
  "  float nearest = cellSize;",
  "  for (int side = 0; side < 2; side++) for (int along = -1; along <= 1; along++) {",
  "    vec2 edge = cell + vec2(float(side), float(along));",
  "    if (wallXAt(edge) > 0.5)",
  "      nearest = min(nearest, wallBoxDistance(p, edge * cellSize - h, (edge + vec2(0.0, 1.0)) * cellSize + h));",
  "    edge = cell + vec2(float(along), float(side));",
  "    if (wallYAt(edge) > 0.5)",
  "      nearest = min(nearest, wallBoxDistance(p, edge * cellSize - h, (edge + vec2(1.0, 0.0)) * cellSize + h));",
  "  }",
  "  return nearest;",
  "}",
  "",
  "float shadowNoise(vec2 p) {",
  "  vec3 q = fract(vec3(p.xyx) * 0.1031);",
  "  q += dot(q, q.yzx + 33.33);",
  "  return fract((q.x + q.y) * q.z);",
  "}",
  "",
  "vec2 panelPoint(vec2 seed, vec2 stratum, vec2 halfPanel) {",
  "  vec2 jitter = vec2(shadowNoise(seed + stratum * vec2(29.0, 71.0)), shadowNoise(seed.yx + stratum * vec2(43.0, 17.0) + 9.0));",
  "  return (stratum + jitter - 1.0) * halfPanel;",
  "}",
  "",
  "vec4 wallBoxHits4(vec2 origin, vec4 invX, vec4 invY, vec2 lo, vec2 hi) {",
  "  vec4 tx0 = (lo.x - origin.x) * invX, tx1 = (hi.x - origin.x) * invX;",
  "  vec4 ty0 = (lo.y - origin.y) * invY, ty1 = (hi.y - origin.y) * invY;",
  "  vec4 enter = max(vec4(0.0), max(min(tx0, tx1), min(ty0, ty1)));",
  "  vec4 leave = min(vec4(1.0), min(max(tx0, tx1), max(ty0, ty1)));",
  "  return step(enter, leave + vec4(0.0000001));",
  "}",
  "",
  "vec4 lampTransmission(vec3 receiver, vec3 lightPosition) {",
  "  vec2 halfPanel = vec2(1.0 / 12.0) * cellSize;",
  "  vec2 seed = floor(receiver.xy * 0.5) + lightPosition.xy * 0.017;",
  "  vec2 p0 = lightPosition.xy + panelPoint(seed, vec2(0.0, 0.0), halfPanel);",
  "  vec2 p1 = lightPosition.xy + panelPoint(seed, vec2(1.0, 0.0), halfPanel);",
  "  vec2 p2 = lightPosition.xy + panelPoint(seed, vec2(0.0, 1.0), halfPanel);",
  "  vec2 p3 = lightPosition.xy + panelPoint(seed, vec2(1.0, 1.0), halfPanel);",
  "  vec2 first = floor(receiver.xy / cellSize), last = floor(lightPosition.xy / cellSize);",
  "  // The nine local lamps are in this cell or its immediate neighbours.",
  "  // All walls reach the ceiling, so the four shadow rays share one XY search.",
  "  if (any(greaterThan(abs(first - last), vec2(1.0))) || receiver.z < 0.0 || receiver.z > wallH) {",
  "    return vec4(wallVisibility(receiver, vec3(p0, lightPosition.z)), wallVisibility(receiver, vec3(p1, lightPosition.z)),",
  "                 wallVisibility(receiver, vec3(p2, lightPosition.z)), wallVisibility(receiver, vec3(p3, lightPosition.z)));",
  "  }",
  "  vec4 dx = vec4(p0.x, p1.x, p2.x, p3.x) - receiver.x;",
  "  vec4 dy = vec4(p0.y, p1.y, p2.y, p3.y) - receiver.y;",
  "  vec4 invX = 1.0 / mix(vec4(0.000001), dx, step(vec4(0.000001), abs(dx)));",
  "  vec4 invY = 1.0 / mix(vec4(0.000001), dy, step(vec4(0.000001), abs(dy)));",
  "  vec2 low = min(first, last), high = max(first, last), h = vec2(wallHalf);",
  "  vec4 visible = vec4(1.0);",
  "  for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) for (int along = -1; along <= 2; along++) {",
  "    vec2 edge = low + vec2(float(edgeIndex), float(along));",
  "    if (edge.x <= high.x + 1.0 && edge.y <= high.y + 1.0 && wallXAt(edge) > 0.5)",
  "      visible *= 1.0 - wallBoxHits4(receiver.xy, invX, invY, edge * cellSize - h, (edge + vec2(0.0, 1.0)) * cellSize + h);",
  "    edge = low + vec2(float(along), float(edgeIndex));",
  "    if (edge.y <= high.y + 1.0 && edge.x <= high.x + 1.0 && wallYAt(edge) > 0.5)",
  "      visible *= 1.0 - wallBoxHits4(receiver.xy, invX, invY, edge * cellSize - h, (edge + vec2(1.0, 0.0)) * cellSize + h);",
  "    if (dot(visible, vec4(1.0)) < 0.5) return vec4(0.0);",
  "  }",
  "  return visible;",
  "}",
  "float lampVisibility(vec3 a, vec3 b) { return dot(lampTransmission(a,b),vec4(0.25)); }",
  "",
  "float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }",
  "float vnoise(vec2 p) {",
  "  vec2 i = floor(p);",
  "  vec2 f = fract(p);",
  "  f = f * f * (3.0 - 2.0 * f);",
  "  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);",
  "}",
  "float fbm(vec2 p) { return (vnoise(p) * 0.5 + vnoise(p * 2.03) * 0.25 + vnoise(p * 4.01) * 0.125) / 0.875; }",
  "float cameraLightProfile(vec3 d) {",
  "  // Smooth flood across the view: no hot spot, reflector ring or sharp disc.",
  "  return smoothstep(flashCone.x, flashCone.y, dot(d, flashDir));",
  "}",
  "float cameraLightAttenuation(float d) {",
  "  float fade = 1.0 - smoothstep(flashRange * 0.5, flashRange, d);",
  "  return fade / (1.0 + d * d / (flashFalloff * flashFalloff));",
  "}",
  // PROCEDURAL WET-PATCH MASK: world-space scale 260, onset 0.60, full wetness 0.72.
  "float wetPatchMask(vec2 p) { return smoothstep(0.66, 0.76, fbm(p / 260.0 + 3.7)); }",
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
  "",
  "vec3 decodeBounce(vec3 c) { return 0.25*c/max(vec3(1.0)-c,vec3(0.02)); }",
  "vec3 surfaceBounce(vec3 p, vec3 n, bool architectural) {",
  "  vec2 uv = clamp(p.xy/(gridSize*cellSize),vec2(0.5/giSize),vec2(1.0-0.5/giSize));",
  "  vec3 result;",
  "  if (architectural && abs(n.z)<0.5) {",
  "    float face=abs(n.x)>0.5?(n.x>0.0?0.0:1.0):(n.y>0.0?2.0:3.0);",
  "    float unit=gridSize*cellSize/giWallSize;",
  "    float plane=floor((abs(n.x)>0.5?p.x:p.y)/unit+0.5);",
  "    float along=clamp((abs(n.x)>0.5?p.y:p.x)/unit,0.5,giWallSize-0.5);",
  "    float h=clamp(p.z/wallH*3.0-0.5,0.0,2.0);",
  "    float u=(face*(giWallSize+1.0)+plane+0.5)/(4.0*(giWallSize+1.0));",
  "    vec3 c0=decodeBounce(texture2D(wallGIMap,vec2(u,along/(giWallSize*3.0)),-16.0).rgb);",
  "    vec3 c1=decodeBounce(texture2D(wallGIMap,vec2(u,(giWallSize+along)/(giWallSize*3.0)),-16.0).rgb);",
  "    vec3 c2=decodeBounce(texture2D(wallGIMap,vec2(u,(2.0*giWallSize+along)/(giWallSize*3.0)),-16.0).rgb);",
  "    result=mix(mix(c0,c1,min(h,1.0)),c2,max(h-1.0,0.0));",
  "  } else {",
  "    vec3 floorLight=decodeBounce(texture2D(giMap,vec2(uv.x,uv.y*0.5),-16.0).rgb);",
  "    vec3 ceilLight=decodeBounce(texture2D(giMap,vec2(uv.x,0.5+uv.y*0.5),-16.0).rgb);",
  "    result=architectural?(n.z>0.0?floorLight:ceilLight):mix(floorLight,ceilLight,clamp(p.z/wallH,0.0,1.0));",
  "  }",
  "  return result*texture2D(giDynamic,uv).r;",
  "}",
  "",
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
  "  float wet = 0.0;",
  "  if (isLevel && wallpaper > 0.5) {",
  "    if (gn.z > 0.5) {",
  "      float fiber = clamp(lum(tex.rgb) / 0.62, 0.6, 1.4);",
  "      float wear = 0.84 + 0.28 * fbm(wPos.xy / 80.0);",
  "      float mott = fbm(wPos.xy / 140.0);",
  "      albedo = vec3(0.13, 0.105, 0.065) * fiber * wear * (0.85 + 0.3 * mott);",
  "      wet = wetPatchMask(wPos.xy);",
  "      albedo *= mix(1.0, 0.62, wet);",
  "      albedo = mix(albedo, vec3(lum(albedo)), 0.25 * wet);",   // damp fibers lose a little colour
  "      rough = mix(0.98, 0.72, wet);",                          // was 0.42: matted, not glossy
  "      f0 = mix(0.012, 0.022, wet);",                           // was 0.05
  "      bump = mix(0.16, 0.06, wet);",
  "    } else if (gn.z < -0.5) {",
  "      vec3 tileAvg = pow(texture2D(texture, vertTexCoord.st, 8.0).rgb,vec3(2.2));",
  "      albedo = mix(tileAvg,albedo,0.35);",
  "      albedo *= (0.6 / max(lum(tileAvg),0.05)) * vec3(1.0,1.0,0.98);",
  // wet patches now also have a leak on the ceiling
  "      float s = fbm(wPos.xy / 260.0 + 3.7);",          // same field as wetPatchMask
  "      float stain = smoothstep(0.70, 0.80, s);",
  "      float ring = smoothstep(0.70, 0.72, s) - smoothstep(0.73, 0.75, s);",
  "      albedo *= mix(vec3(1.0), vec3(0.78, 0.66, 0.48), stain * 0.22 + ring * 0.35);",
  "      vec2 tileP = mod(wPos.xy + cellSize / 12.0, vec2(cellSize / 6.0));",
  "      vec2 tileEdge = min(tileP, vec2(cellSize / 6.0) - tileP);",
  "      float gridAA = max(max(fwidth(wPos.x), fwidth(wPos.y)), 0.5);",
  "      float ceilingGrid = 1.0 - smoothstep(0.35, 0.35 + gridAA, min(tileEdge.x, tileEdge.y));",
  "      albedo *= mix(1.0, 0.76, ceilingGrid);",
  "      rough = 0.9;",
  "      bump = 0.1;",
  "    } else {",
  "      vec3 paperAvg = pow(texture2D(texture, vertTexCoord.st, 8.0).rgb,vec3(2.2));",
  "      albedo = mix(paperAvg,albedo,0.45);",
  "      albedo *= 0.42 / max(lum(paperAvg),0.05);",
  "      vec2 t2 = vec2(gn.y, -gn.x);",
  "      float along = dot(wPos.xy, t2);",
  "      float paperLuma = lum(albedo);",
  "      albedo = mix(vec3(paperLuma), albedo, 0.18) * vec3(1.08, 1.02, 0.72);",
  "      float paper = vnoise(vec2(along, wPos.z) * 0.18);",
  "      albedo *= 0.97 + 0.05 * paper;",
  "      float grime = 1.0 - smoothstep(0.0, 100.0, wPos.z);",
  "      albedo *= (0.88 + 0.24 * fbm(vec2(along, wPos.z) / 600.0)) * (1.0 - 0.22 * grime);",
  "      rough = 0.92;",
  "      bump = 0.12;",
  // baseboards: disabled because the backrooms dont have them
  // "      float bb = 1.0 - smoothstep(10.0, 12.0, wPos.z);",
  // "      albedo = mix(albedo, vec3(0.028, 0.021, 0.012), bb);",
  // "      rough = mix(rough, 0.55, bb);",
  "    }",
  "  }",
  "  vec3 n = gn;",
  "  float bumpFade = 1.0 - smoothstep(350.0, 1100.0, dist);",
  "  if (bump > 0.0 && bumpFade > 0.0) {",
  "    vec2 uv = vertTexCoord.st;",
  "    float h0 = lum(texture2D(texture, uv, 1.0).rgb);",
  "    float hx = lum(texture2D(texture, uv + vec2(texOffset.x * 2.0, 0.0), 1.0).rgb);",
  "    float hy = lum(texture2D(texture, uv + vec2(0.0, texOffset.y * 2.0), 1.0).rgb);",
  "    if (isLevel && abs(gn.z)<0.5) {",
  "      h0=0.0; hx=0.015*(vnoise(wPos.xy*0.7+wPos.z)-0.5); hy=0.015*(vnoise(wPos.yx*0.8-wPos.z)-0.5);",
  "    }",
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
  "  vec3 lampCol = vec3(1.0, 0.98, 0.80);",
  "  vec3 direct = vec3(0.0);",
  "  float irr = 0.0;",
  "  vec2 a = wPos.xy + gn.xy * 2.0;",
  "  vec2 cc = floor(a / cellSize);",
  "  float hr = cellSize * 1.5;",
  "  vec3 R = reflect(-Vn, n);",
  "  float ptZ = wallH - 6.0;",
  "  vec2 panelHalf = vec2(cellSize / 12.0);",
  "  for (int j = -1; j <= 1; j++) {",
  "    for (int i = -1; i <= 1; i++) {",
  "      vec2 d = vec2(float(i), float(j));",
  "      vec2 c = cc + d;",
  "      float p = cellVal(c);",
  "      if (p <= 0.01) continue;",
  "      vec2 b = (c + 0.5) * cellSize;",
  "      float hd = length(b - wPos.xy);",
  "      if (hd >= hr) continue;",
  "      vec3 receiver=vec3(a,wPos.z+gn.z*2.0);",
  "      vec4 visibility=lampTransmission(receiver,vec3(b,lampZ));",
  "      float vis=dot(visibility,vec4(0.25));",
  "      if (vis <= 0.0) continue;",
  "      if (gn.z < -0.5) {",
  "        float pd=length(max(abs(wPos.xy-b)-panelHalf,vec2(0.0)));",
  "        direct+=albedo*lampCol*(p*0.9*exp(-pd/60.0)*vis);",
  "        continue;",
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
  "      vec2 seed=floor(receiver.xy*0.5)+b*0.017;",
  "      vec2 p0=b+panelPoint(seed,vec2(0.0,0.0),panelHalf), p1=b+panelPoint(seed,vec2(1.0,0.0),panelHalf);",
  "      vec2 p2=b+panelPoint(seed,vec2(0.0,1.0),panelHalf), p3=b+panelPoint(seed,vec2(1.0,1.0),panelHalf);",
  "      vec4 ax=vec4(p0.x,p1.x,p2.x,p3.x)-wPos.x, ay=vec4(p0.y,p1.y,p2.y,p3.y)-wPos.y;",
  "      float az=lampZ-wPos.z;",
  "      vec4 d2=ax*ax+ay*ay+az*az, inv=inversesqrt(max(d2,vec4(1.0)));",
  "      vec4 ndl=max((n.x*ax+n.y*ay+n.z*az)*inv,vec4(0.0));",
  "      vec4 sourceCos=max(az*inv,vec4(0.0));",
  "      vec4 horizontal=sqrt(ax*ax+ay*ay)/hr, fade=max(vec4(0.0),1.0-pow(horizontal,vec4(4.0)));",
  "      vec4 areaAtt=fade*fade/(1.0+d2/(cellSize*cellSize*0.9));",
  "      float areaEnergy=dot(ndl*sourceCos*areaAtt*visibility,vec4(0.25));",
  "      direct+=albedo*lampCol*(1.15*0.96*p*areaEnergy);",
  "      direct+=brdf(n,Vn,L,Ls,vec3(0.0),rough,f0)*lampCol*(1.15*PI*p*att*vis);",
  "      irr += p * att * vis;",
  "    }",
  "  }",
  "  vec3 ambient=albedo*surfaceBounce(wPos,gn,isLevel);",
  "",
  "  vec3 receiver = vec3(a, wPos.z + gn.z * 2.0);",
  "  vec3 Lf = flashPos - wPos;",
  "  float df = length(Lf);",
  "  vec3 Lfn = Lf / max(df, 0.001);",
  "  float prof = flash > 0.0001 && df < flashRange ? cameraLightProfile(-Lfn) : 0.0;",
  "  if (prof > 0.002) {",
  "    float shadow = wallVisibility(receiver, flashPos);",
  "    float atten = cameraLightAttenuation(df);",
  "    direct += brdf(n, Vn, Lfn, Lfn, albedo, rough, f0) * flashCol * (PI * flash * prof * atten * shadow);",
  "  }",
  "  float ao = 1.0;",
  "  if (isLevel) {",
  "    if (abs(gn.z) > 0.5) {",
  "      float distanceToWall = nearestWall(wPos.xy);",
  "      ao = mix(0.78, 1.0, smoothstep(0.0, 18.0, distanceToWall));",
  "    } else {",
  "      ao = mix(0.78, 1.0, smoothstep(0.0, 16.0, wPos.z)) * mix(0.84, 1.0, smoothstep(0.0, 12.0, wallH - wPos.z));",
  "      float cornerClearance = nearestWall(wPos.xy + gn.xy * 14.0);",
  "      ao *= mix(0.86, 1.0, smoothstep(0.0, 12.0, cornerClearance));",
  "    }",
  "  }",
  "  vec3 col = direct * mix(1.0, ao, 0.15) + ambient * ao + albedo * emissive * 1.6;",
  "  col = mix(col, vec3(0.02, 0.8, 1.0), wet * wetDebug);",
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
  "      float visibility = wallVisibility(sp, sp + dlp);",
  "      scat += visibility * lp / (1.0 + dot(dlp, dlp) / 48400.0);",
  "    }",
  "    col += lampCol * scat * rayLen / 10.0 * 0.00008;",
  "  }",
  "  col = 1.0 - exp(-col * exposure * 1.6);",
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

  "  float rad = soft * (0.6 + 1.6 * r2);",                                   // softer toward the edges
  "  vec2 j = texOffset * vec2(rad, max(rad, 0.75));",
  "  vec2 lo = texOffset, hi = vec2(1.0) - texOffset;",
  "  vec3 col = (texture2D(texture, clamp(uv + j, lo, hi)).rgb + texture2D(texture, clamp(uv - j, lo, hi)).rgb) * 0.275 + texture2D(texture, uv).rgb * 0.45;",
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
  "uniform float footage;",
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
  "  vec3 bloom = vec3(0.0);",
  "  for (int k = 0; k < 16; k++) {",
  "    float a = float(k) * 2.39996;",
  "    vec2 o = vec2(cos(a), sin(a)) * (3.0 + float(k) * 2.2) * texOffset * 2.0;",
  "    vec3 s = texture2D(texture, uv + o).rgb;",
  "    float l = max(max(s.r, s.g), s.b);",
  "    bloom += s * smoothstep(0.88, 1.0, l) / (1.0 + float(k) * 0.12);",
  "  }",
  "  bloom /= 9.0;",
  "  col += bloom * vec3(0.98, 1.0, 0.88) * mix(0.35, 0.20, footage) + bloom * vec3(0.2, 0.03, 0.0) * mix(0.25, 0.05, footage);",
  "  float luma = dot(col, vec3(0.299, 0.587, 0.114));",
  "  col = mix(vec3(luma), col,(mix(0.92, 1.0, footage) - 0.4 * danger) * 1.70);",
  "  col *= mix(vec3(1.02, 1.0, 0.92), vec3(1.05, 1.02, 0.84), footage);",
  "  col = mix(col, vec3(luma * 1.2, luma * 0.35, luma * 0.3), 0.35 * hit + 0.15 * danger * danger);",
  "  col = clamp(col, 0.0, 1.0);",
  "  col = mix(col, col * col * (3.0 - 2.0 * col), 0.25);",
  "  col *= 1.0 - vhs * 0.05 * (0.5 + 0.5 * sin(uv.y / texOffset.y * 3.14159));",
  "  col += band * 0.04;",
  "  float n1 = rnd(uv * 731.0 + time) - 0.5;",
  "  float n2 = rnd(uv * 417.0 - time * 1.3) - 0.5;",
  "  col += vec3(n1, (n1 + n2) * 0.5, n2) * (0.012 + 0.03 * gain) * (1.0 - luma) + n1 * 0.06 * danger;",
  "  float v = 1.0 - smoothstep(0.35, 1.05, length(dir * vec2(1.2, 1.0)) + 0.15 * danger);",
  "  col *= mix(0.78, 1.0, v);",
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
  setupSynth();
  for (int k = 0; k < NAMES.length; k++) {
    String n = NAMES[k].toLowerCase();
    faces[k]  = loadImage(n + ".jpg");
    voices[k] = new Voice3D(n + ".mp3");
  }

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
  tape  = new PShader(this, POST_VERT, TAPE_FRAG);

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
  for (int k = 0; k < packEyes.length; k++) packEyes[k] = new Eye();

  loadSaves();
  pwSel = unlockedDays() - 1;
  lastMs = millis();
}

// Compute the actual camera once before AI/interactions. The lamp is attached to this pose.
void updateCameraLight(float dt) {
  float pulse = kickEnv * chaseLvl;
  float dgV = max(danger(threatD), chaseLvl * 0.4);
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
  camX = ex; camY = ey; camZ = ez;
  camDX = cos(yawR) * cos(pitchR); camDY = sin(yawR) * cos(pitchR); camDZ = sin(pitchR);
  cameraRoll = rollR;
  cameraRightX = rx; cameraRightY = ry;
  updateFlashlight(dt, camX, camY, camZ, camDX, camDY, camDZ);
}

void updateFlashlight(float dt, float ex, float ey, float ez, float lx, float ly, float lz) {
  // No interpolation or extra sway: position and direction are exactly the camera's.
  flashPos.set(ex, ey, ez);
  flashDir.set(lx, ly, lz).normalize();
}

float flashlightStrength() { return flashlightOn ? flicker : 0; }

// CPU equivalent of the flood profile, used for illumination-aware interactions.
float cameraLightIntensityAt(float x, float y, float z) {
  float dx = x - flashPos.x, dy = y - flashPos.y, dz = z - flashPos.z;
  float d = sqrt(dx * dx + dy * dy + dz * dz);
  float strength = flashlightStrength();
  if (strength <= 0 || d >= FLASH_RANGE) return 0;
  float cosine = d > 0.001 ? (dx * flashDir.x + dy * flashDir.y + dz * flashDir.z) / d : 1;
  float cone = constrain((cosine - FLASH_OUTER_COS) / (FLASH_INNER_COS - FLASH_OUTER_COS), 0, 1);
  cone = cone * cone * (3 - 2 * cone);
  float fade = constrain((d - FLASH_RANGE * 0.5) / (FLASH_RANGE * 0.5), 0, 1);
  fade = 1 - fade * fade * (3 - 2 * fade);
  return FLASH_POWER * strength * cone * fade / (1 + sq(d / FLASH_FALLOFF));
}

boolean flashlightAimsAt(float x, float y, float z, float cosine) {
  if (cameraLightIntensityAt(x, y, z) < 0.025) return false;
  PVector targetDelta = new PVector(x - flashPos.x, y - flashPos.y, z - flashPos.z);
  float d = targetDelta.mag();
  return d > 0.001 && targetDelta.dot(flashDir) > cosine * d
    && lineOfSight(flashPos.x, flashPos.y, x, y);
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
  initAudioBuses();
  fxBus.patch(out);
  voiceBus.patch(out);
  buildSynthGraph();
}

void buildSynthGraph() {
  hum  = new Oscil(120, 0, Waves.SINE);
  hum2 = new Oscil(240, 0, Waves.TRIANGLE);
  heart = new Oscil(52, 0, Waves.SINE);
  hum.patch(fxMix);
  hum2.patch(fxMix);
  heart.patch(fxMix);

  stepAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.BROWN).patch(new MoogFilter(280, 0.25)).patch(stepAmp).patch(fxMix);
  breathAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.PINK).patch(new MoogFilter(1400, 0.15)).patch(breathAmp).patch(fxMix);
  staticAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.WHITE).patch(staticAmp).patch(fxMix);

  MoogFilter stingLP = new MoogFilter(2200, 0.3);
  Summer stingMix = new Summer();
  stingMix.patch(stingLP);
  for (int k = 0; k < 3; k++) {
    sting[k] = new Oscil(STING_F[k], 0, Waves.SAW);
    sting[k].patch(stingMix);
  }
  stingLP.patch(fxMix);
  boom = new Oscil(48, 0, Waves.SINE);
  boom.patch(fxMix);
  screech = new Oscil(1800, 0, Waves.TRIANGLE);
  screech.patch(fxMix);

  droneLP = new MoogFilter(300, 0.5);
  drone1 = new Oscil(55, 0, Waves.SAW);
  drone2 = new Oscil(55.7, 0, Waves.SAW);
  Summer droneMix = new Summer();
  droneMix.patch(droneLP);
  drone1.patch(droneMix);
  drone2.patch(droneMix);
  droneLP.patch(fxMix);
  kick = new Oscil(60, 0, Waves.SINE);
  kick.patch(fxMix);
  tickAmp = new Multiplier(0);
  new Noise(1, Noise.Tint.WHITE).patch(new MoogFilter(7000, 0.1)).patch(tickAmp).patch(fxMix);

  achOsc = new Oscil(784, 0, Waves.TRIANGLE);
  achOsc.patch(fxMix);

  // footstep echo: wetter and longer in open halls
  stepEcho = new Delay(0.6, 0.3, true, false);
  echoWet = new Multiplier(0);
  stepAmp.patch(stepEcho).patch(echoWet).patch(fxMix);

  // the nerdolas' footsteps
  for (int k = 0; k < eSteps.length; k++) eSteps[k] = new Steps3D();

  // distant one-shots: slams, pipe clanks, someone running far away
  distLP = new MoogFilter(300, 0.2);
  distPan = new Pan(0);
  distNAmp = new Multiplier(0);
  Summer distantMix = new Summer();
  distantMix.patch(distLP);
  new Noise(1, Noise.Tint.BROWN).patch(distNAmp).patch(distantMix);
  distO = new Oscil(50, 0, Waves.SINE);
  distO.patch(distantMix);
  distLP.patch(distPan).patch(fxMix);
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
  for (Steps3D s : eSteps) if (s != null) {
    s.env = 0;
    s.amp.setValue(0);
  }
  distType = -1;
  if (distO != null) distO.setAmplitude(0);
  if (distNAmp != null) distNAmp.setValue(0);
  if (echoWet != null) echoWet.setValue(0);
  setGainDb(ambience, volDb(V_AMB));
}

void pauseVoices() {
  for (Voice3D v : voices) v.pause();
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
  if (survived >= 180 && usedCount[COXINHA] >= 3 && usedCount[SALADA] + usedCount[LAGRIMAS] + usedCount[CESTA] + usedCount[MONSTER] == 0) unlock(19);
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

  generateWorld();
  level = buildLevel();

  lampType = new int[GRID][GRID];
  lampP = new float[GRID][GRID];
  float zs = random(1000);
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    float r = random(1), z = noise(i * 0.14 + zs, j * 0.14 + zs * 0.5);
    if (blackout) lampType[i][j] = 2;
    else if (z > 0.64) lampType[i][j] = r < 0.75 ? 2 : 1;      // dead zone
    else if (z < 0.32) lampType[i][j] = r < 0.4 ? 1 : 0;       // failing ballasts
    else lampType[i][j] = r < 0.04 ? 2 : (r < 0.12 ? 1 : 0);
  }

  // Keep dark hiding corners inside the zoned layout.
  for (int i = 1; i < GRID - 1; i++) for (int j = 1; j < GRID - 1; j++)
    if (!isWall(i, j) && openNeighbors(i, j) == 1 && random(1) < DEADEND_DARK) lampType[i][j] = 2;

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
  mainEye = new Eye();
  for (int k = 0; k < packEyes.length; k++) packEyes[k] = new Eye();
  anyChase = false;

  survived = 0;
  drops.clear();
  dropBag.clear();
  parts.clear();
  int nDrops = round(DROPS * mapScale());
  for (int k = 0; k < nDrops; k++) spawnDrop();
  bakeGI(); // Measure the ordinary level before choosing blessing locations.
  placeSecrets();
  placeDecals();
  placeProps();
  markSecrets();
  giLive = 1;
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
  java.util.Arrays.fill(slotShow, 0);
  java.util.Arrays.fill(slotPop, 0);
  java.util.Arrays.fill(lastInv, 0);
  slotOrder.clear();
  inv[LATA] = START_CANS;
  itemSeen[LATA] = true;
  useType = -1;
  syncSlots();
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
  fov = radians(BASE_FOV);
  exposureAdapt = 1;
  cameraExposureTarget = 1; meterNext = 0;
  roll = bobPhase = stepEnv = hbPhase = staticBurst = chewTimer = 0;
  peekSide = peekDir = 0;
  paused = false;
  peekAmt = 0;
  peekOff.set(0, 0);
  peekL = peekR = null;
  lastStep = 0;
  flicker = 1;
  flickerUntil = 0;
  moving = sprinting = crouching = false;
  updateCameraLight(0);
  crouchToggle = false;
  releaseKeys();
  silenceSynth();

  distType = -1;
  nextDistant = random(8, 16);
  roomOpen = 0;
  acousticRefresh = 0; acousticFlowI = acousticFlowJ = -1;
  pauseVoices();
  for (Enemy e : enemies) {
    voices[e.ch].snap(-80, 0, 12000);
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
  voices[killerCh].snap(6, 0, 12000);
  voices[killerCh].play();
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
// OPEN-FLOOR WORLD GENERATION


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
  beginLevelChunks(floorS, ceilS, wallS);
  for (int i = 1; i < GRID - 1; i++) for (int j = 1; j < GRID - 1; j++) {
    float x = i * CELL, y = j * CELL;
    addQuad(floorS, new PVector(x, y, 0), new PVector(CELL, 0, 0), new PVector(0, CELL, 0), 1, 1);
    addQuad(ceilS, new PVector(x, y, WALL_H), new PVector(CELL, 0, 0), new PVector(0, CELL, 0), 1, 1);
  }
  appendWallMesh(wallS);
  floorS.endShape(); ceilS.endShape(); wallS.endShape();
  finishLevelChunks();
  PShape grp = createShape(GROUP);
  grp.addChild(floorS); grp.addChild(ceilS); grp.addChild(wallS);
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
  if (buildingLevelChunks) addChunkQuad(s, o, a, b, uRep, vRep);
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
  PGraphics g = createGraphics(128, 128);
  g.beginDraw();
  g.background(70);               // frame edge, was 110
  g.noStroke(); g.fill(160); g.rect(2, 2, 124, 124);   // was 210
  g.fill(255); g.rect(4, 4, 120, 120);
  g.stroke(232); g.strokeWeight(1);
  for (int x = 9; x < 124; x += 5) g.line(x, 4, x, 124);
  for (int y = 9; y < 124; y += 5) g.line(4, y, 124, y);
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
    if (!wallFace(c[0], c[1], d[0], d[1])) continue;
    String face = c[0] + "," + c[1] + "," + d[0] + "," + d[1];
    if (used.contains(face)) continue;
    used.add(face);
    Decal dc = new Decal();
    dc.nx = -d[0];
    dc.ny = -d[1];
    dc.cx = (c[0] + 0.5) * CELL + d[0] * (CELL * 0.5 - WALL_THICKNESS / 2 - 2);
    dc.cy = (c[1] + 0.5) * CELL + d[1] * (CELL * 0.5 - WALL_THICKNESS / 2 - 2);
    dc.z = random(140, 205);
    dc.w = CELL - WALL_THICKNESS - 16;
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
      if (!wallFace(c[0], c[1], d[0], d[1])) continue;
      String face = (vent ? "v" : "o") + c[0] + "," + c[1] + "," + d[0] + "," + d[1];
      if (used.contains(face)) continue;
      used.add(face);
      Decal dc = new Decal();
      dc.nx = -d[0];
      dc.ny = -d[1];
      float slide = random(-CELL * 0.22, CELL * 0.22);
      dc.cx = (c[0] + 0.5) * CELL + d[0] * (CELL * 0.5 - WALL_THICKNESS / 2 - 1.5) + dc.ny * slide;
      dc.cy = (c[1] + 0.5) * CELL + d[1] * (CELL * 0.5 - WALL_THICKNESS / 2 - 1.5) - dc.nx * slide;
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
      if (!wallFace(c[0], c[1], d[0], d[1])) continue;
      float x = (c[0] + 0.5) * CELL + d[0] * (CELL * 0.5 - WALL_THICKNESS / 2 - 2.5);
      float y = (c[1] + 0.5) * CELL + d[1] * (CELL * 0.5 - WALL_THICKNESS / 2 - 2.5);
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
    if (d > 175 || !lineOfSight(player.x, player.y, ct.x, ct.y)) continue;
    float facing = ((ct.x - player.x) * fx + (ct.y - player.y) * fy) / max(d, 1);
    if (facing < 0.35) continue;
    if (d < bestD) {
      bestD = d;
      nearCert = k;
    }
  }
  if (exitOpen && dist(player.x, player.y, exitX(), exitY()) < 150 && lineOfSight(player.x, player.y, exitX(), exitY())) escapeWin();
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
    for (int[] d : DIRS) if (canStep(i, j, i + d[0], j + d[1])) _open++;
    if (_open == 4) continue;
    if (_open < 3 && tries < 500) continue;
    int si = 0, sj = 0;
    for (int[] d : DIRS) {
      int ni = i + d[0], nj = j + d[1];
      if (canStep(i, j, ni, nj) && f[ni][nj] == f[i][j] - 1) {
        si = d[0];
        sj = d[1];
        break;
      }
    }
    ArrayList<int[]> walls = new ArrayList<int[]>();
    for (int[] d : DIRS) if (wallFace(i, j, d[0], d[1]) && d[0] * si + d[1] * sj == 0) walls.add(d);
    if (walls.isEmpty()) continue;
    int[] d = walls.get((int) random(walls.size()));
    float cx = (i + 0.5) * CELL + d[0] * (CELL * 0.5 - WALL_THICKNESS / 2 - 3);
    float cy = (j + 0.5) * CELL + d[1] * (CELL * 0.5 - WALL_THICKNESS / 2 - 3);
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
        if (!wallFace(i, j, d[0], d[1])) continue;
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
  float cx = (exitI + 0.5) * CELL + exitDI * (CELL * 0.5 - WALL_THICKNESS / 2 - 3);
  float cy = (exitJ + 0.5) * CELL + exitDJ * (CELL * 0.5 - WALL_THICKNESS / 2 - 3);
  float hw = 110;
  beginShape(QUADS);
  texture(exitTex);
  vertex(cx - rx * hw, cy - ry * hw, WALL_H - 8, 0, 0);
  vertex(cx + rx * hw, cy + ry * hw, WALL_H - 8, 1, 0);
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
  PShape oldLabel = lagrimasModel.getChild("water_lable");
  if (oldLabel != null) lagrimasModel.removeChild(lagrimasModel.getChildIndex(oldLabel));   // our own label goes on instead
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
  if (grp == null) return;
  for (int pass = 0; pass < 2; pass++) {
    if (pass == 1) hint(DISABLE_DEPTH_MASK);
    for (PShape ch : grp.getChildren()) {
      boolean glass = "glass".equals(ch.getName());
      if (glass == (pass == 1)) shape(ch);
    }
    if (pass == 1) { flush(); hint(ENABLE_DEPTH_MASK); }
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

    itemLights(dr.x, dr.y, hover + (dr.type == TASER ? 60 * sc : 0), lerp(1, vis, 0.5));

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
void itemLights(float x, float y, float z, float L) {
  int ci = cellOf(x), cj = cellOf(y);
  float lp = lineOfSight(x, y, (ci + 0.5) * CELL, (cj + 0.5) * CELL) ? lampP[ci][cj] : 0;
  // Existing room bounce, without an invented minimum light in dead zones.
  float bounce = 0;
  if (giField != null && giSize > 0) {
    int gx = constrain(floor(x / (CELL * GRID) * giSize), 0, giSize - 1);
    int gy = constrain(floor(y / (CELL * GRID) * giSize), 0, giSize - 1);
    float live = giDynamic == null ? 1 : (giDynamic.pixels[cj * GRID + ci] & 255) / 255.0;
    bounce = giField[gy * giSize + gx] * live;
  }
  float amb = constrain(0.5 * lp + 2 * bounce, 0, 1.5) * L;
  noLights();
  lightFalloff(1, 0, 0);
  ambientLight(70 * amb, 62 * amb, 48 * amb);
  lightFalloff(1, 0, 0.000004);
  pointLight(255 * lp * L, 235 * lp * L, 185 * lp * L, (ci + 0.5) * CELL, (cj + 0.5) * CELL, WALL_H - 3);
  lightFalloff(1, 0, 0);
  float fl = flashlightStrength();
  float d = dist(x, y, z, flashPos.x, flashPos.y, flashPos.z);
  if (fl > 0 && d < FLASH_RANGE && lineOfSight(flashPos.x, flashPos.y, x, y)) {
    // Fixed-pipeline OBJ lighting uses the same camera source, broad spread and short reach.
    float t = constrain((d - FLASH_RANGE * 0.5) / (FLASH_RANGE * 0.5), 0, 1);
    float fade = 1 - t * t * (3 - 2 * t);
    lightFalloff(1, 0, 1.0 / sq(FLASH_FALLOFF));
    float f = 210 * FLASH_POWER * fl * L * fade;
    spotLight(f * FLASH_COLOR.x, f * FLASH_COLOR.y, f * FLASH_COLOR.z,
      flashPos.x, flashPos.y, flashPos.z, flashDir.x, flashDir.y, flashDir.z, acos(FLASH_OUTER_COS), 1);
    lightFalloff(1, 0, 0);
  }
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

  float lvl = constrain(localLight + 0.35 * flashlightStrength(), 0.12, 1.3);
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
    showMsg("PILHADO  —  VOCÊ OS VÊ ATRAVÉS DAS PAREDES   ·   LATA VAZIA [G]");
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
  peekAmt = lerp(peekAmt, peekSide != 0 ? 1 : 0, 1 - exp(-dt * (peekSide != 0 ? 4 : 9)));
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
  // Resolve flicker once before gameplay tests; render sees the identical intensity.
  float flashDanger = danger(threatD);
  if (now < flickerUntil) {
    flicker = random(1) < 0.5 ? random(0.05, 0.4) : 1;
  } else {
    flicker = 1;
    if (random(1) < (3 * flashDanger + 2 * chaseLvl) * dt) flickerUntil = now + random(80, 400);
  }
  float strafe = (kRight ? 1 : 0) - (kLeft ? 1 : 0);
  roll = lerp(roll, strafe * 0.03, 1 - exp(-dt * 7));
  updateCameraLight(dt); // Shared camera source, direction and instant state for AI/secrets/render.
  updateFlow();
  if (survived > graceTime) for (Enemy e : enemies) updateAI(e, dt);

  nearE = null;
  nearD = 1e9;
  threatD = 1e9;
  anyChase = false;
  for (Enemy e : enemies) {
    float d = dist(player.x, player.y, e.pos.x, e.pos.y);
    if (d < KILL_DIST && now >= e.stunUntil && lineOfSight(player.x, player.y, e.pos.x, e.pos.y)) {
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
    if (dist(player.x, player.y, dr.x, dr.y) < 110 && inv[dr.type] < MAX_STACK && lineOfSight(player.x, player.y, dr.x, dr.y)) {
      inv[dr.type]++;
      syncSlots();
      collectedType[dr.type]++;
      itemSeen[dr.type] = true;
      drops.remove(k);
      stepEnv = 0.3;
      showMsg("+ " + ITEM_NAMES[dr.type].toUpperCase() + "   [" + keyFor(dr.type) + "]");
      spawnDrop();
      itemsCollected++;
      pickupTimes.add(now);
      while (pickupTimes.size() > 0 && now - pickupTimes.get(0) > 45000) pickupTimes.remove(0);
      if (pickupTimes.size() >= 6) unlock(5);
      if (itemsCollected >= 25) unlock(6);
      if (collectedType[TASER] >= 3 && collectedType[COXINHA] + collectedType[SALADA] + collectedType[LAGRIMAS] + collectedType[CESTA] + collectedType[MONSTER] == 0) unlock(18);
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
    if (dc.msg >= 0 && dist(player.x, player.y, dc.cx, dc.cy) < CELL * 1.3 && lineOfSight(player.x, player.y, dc.cx, dc.cy)) {
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
  spotFlash = max(0, spotFlash - dt * 2.5);

  float targetFov = radians(sprinting ? BASE_FOV + 10 : BASE_FOV) - dg * radians(6);
  fov = lerp(fov, targetFov, 1 - exp(-dt * 5));

  updateLampGrid();

  float adaptationSpeed = cameraExposureTarget < exposureAdapt ? 2.4 : 0.8;
  exposureAdapt = lerp(exposureAdapt, cameraExposureTarget, 1 - exp(-dt * adaptationSpeed));
  camGain = constrain(map(exposureAdapt, 0.8, 1.6, 0, 1), 0, 1);

  update3DAudio(dt);
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
  return hitsWallSlab(x, y, r);
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
    if (!lineOfSight(x, y, x + fx * s, y + fy * s)) return s;
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
  if (gameMode == FUGA) return min(ENEMY_MAX + 40, ENEMY_START + certsTaken * CERT_SPEEDUP + t * ENEMY_RAMP * 0.75);
  return min(ENEMY_MAX, ENEMY_START + t * ENEMY_RAMP);
}

void updateAI(Enemy e, float dt) {
  int now = millis();
  int c = e.ch;
  if (now < e.stunUntil) {
    e.sees = false;
    e.speedNow = 0;
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

  // ---- sight: 360 degrees, a clear line, and range by how lit you are;
  // The short video light grants no long-range reveal beyond its actual illumination.
  // invisible = never seen; crouching shrinks it
  boolean inBeam = flashlightAimsAt(e.pos.x, e.pos.y, 135, FLASH_OUTER_COS);
  float lit = constrain(max(playerExpo, flashlightStrength() * 0.12), 0, 1);
  float sight = (inBeam ? SIGHT_FLASH : SIGHT_CELLS * lerp(SIGHT_DARK, 1, lit)) * CELL * SIGHT_MUL[c];
  if (crouching) sight *= moving ? CROUCH_SIGHT : CROUCH_STILL_SIGHT;
  float peekEase = peekAmt * peekAmt * (3 - 2 * peekAmt);
  float peekReach = peekOff.mag();
  float headTilt = asin(constrain(peekReach / leanArm(), 0, 1)) * peekEase;
  float headScale = peekReach > 0 ? leanArm() * sin(headTilt) / peekReach : 0;
  float sightX = player.x + peekOff.x * headScale, sightY = player.y + peekOff.y * headScale;
  e.sees = !ghost && !confused && dist(e.pos.x, e.pos.y, sightX, sightY) < sight && lineOfSight(e.pos.x, e.pos.y, sightX, sightY);

  // ---- hearing: only while moving; crouch-walking = same room (Gustavo: one room)
  float hearRange;
  if (crouching) hearRange = c == T_GUSTAVO ? 1 : 0;
  else hearRange = (sprinting ? HEAR_SPRINT : HEAR_WALK) * HEAR_MUL[c];
  if (ghost) hearRange *= GHOST_HEAR;
  boolean hears = moving && !confused && path <= hearRange;

  // ---- proximity bubble
  float touch = ghost ? GHOST_TOUCH : (crouching ? CROUCH_TOUCH : TOUCH_CELLS);
  boolean bumped = !confused && d < CELL * touch && lineOfSight(e.pos.x, e.pos.y, player.x, player.y);


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
  float moved = mv ? min(speed * dt, m) : 0;
  if (mv) {
    PVector previous = e.pos.copy();
    PVector delta = dir.copy().mult(moved / m);
    moveEnemy(e, delta.x, delta.y);
    moved = PVector.dist(previous, e.pos);
  }
  e.speedNow = dt > 0 ? moved / dt : 0;

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
    if (isWall(i, j) || lampType[i][j] == 2 || !lineOfSight(player.x, player.y, (i + 0.5) * CELL, (j + 0.5) * CELL)) continue;
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
    float sz = 220, base = 25;
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
// THE BLESSING OF CABRAL: illuminated wall panels open shortcuts and reveal Pizza do Papponi
// one pizza per phase: POLIWEEK days 0-5, VS. 6, RECUPERAÇÃO, then ENDLESS
int phase() {
  return runDay >= 0 ? runDay : PHASES - 1;
}

float pizzaMul() {
  int n = 0;
  for (boolean b : pizzaGot) if (b) n++;
  return 1 + PIZZA_BONUS * n;
}

// Blessings select pre-existing shadows. These limits are linear irradiance,
// before surface color, camera gain, flashlight or the player's proximity glow.
final float BLESSING_MAX_DIRECT = 0.004;
final float BLESSING_MAX_LIGHT = 0.025;
boolean giPlacementReady;
LightPatch blessingLightProbe;

class BlessingCandidate {
  int i,j,ni,nj;
  float light;
  BlessingCandidate(int i,int j,int ni,int nj,float light) {
    this.i=i;this.j=j;this.ni=ni;this.nj=nj;this.light=light;
  }
}

// Read the same face/height atlas as surfaceBounce(), without changing it.
float blessingBounceLayer(int face,int plane,float along,int layer) {
  float row=constrain(along-0.5,0,giWallSize-1);
  int a=floor(row),b=min(a+1,giWallSize-1);float t=row-a;
  int ca=wallGI.pixels[giWallIndex(face,plane,a,layer)],cb=wallGI.pixels[giWallIndex(face,plane,b,layer)];
  float r=lerp((ca>>16)&255,(cb>>16)&255,t)/255.0;
  float g=lerp((ca>>8)&255,(cb>>8)&255,t)/255.0;
  float blue=lerp(ca&255,cb&255,t)/255.0;
  return 0.25*(0.299*r/max(1-r,0.02)+0.587*g/max(1-g,0.02)+0.114*blue/max(1-blue,0.02));
}

float blessingBounce(float x,float y,float z,int nx,int ny) {
  float unit=CELL/WALL_SUBDIV;
  int face=nx>0?0:nx<0?1:ny>0?2:3;
  int plane=constrain(round((nx!=0?x:y)/unit),0,giWallSize);
  float along=constrain((nx!=0?y:x)/unit,0.5,giWallSize-0.5);
  float h=constrain(z/WALL_H*GI_LAYERS-0.5,0,GI_LAYERS-1);
  int a=floor(h),b=min(a+1,GI_LAYERS-1);
  return lerp(blessingBounceLayer(face,plane,along,a),blessingBounceLayer(face,plane,along,b),h-a);
}

// Reject the face if any part of the 1.2 m symbol receives noticeable fixed
// light. Failing ballasts are evaluated conservatively, not during an off flash.
float blessingWallLight(int i,int j,int di,int dj) {
  int nx=-di,ny=-dj;
  float x=(i+0.5)*CELL+di*(CELL*0.5-WALL_THICKNESS/2);
  float y=(j+0.5)*CELL+dj*(CELL*0.5-WALL_THICKNESS/2),maximum=0;
  if (blessingLightProbe==null) blessingLightProbe=new LightPatch(x,y,EYE_H,nx,ny,0,new float[]{1,1,1});
  LightPatch p=blessingLightProbe;
  p.nx=nx;p.ny=ny;p.nz=0;
  for (int side=-1;side<=1;side++) for (int height=-1;height<=1;height++) {
    p.x=x+ny*side*60;p.y=y-nx*side*60;p.z=EYE_H+height*60;
    bakePatchDirect(p);
    float direct=(0.299*p.dr+0.587*p.dg+0.114*p.db)/0.7;
    if (direct>BLESSING_MAX_DIRECT) return Float.POSITIVE_INFINITY;
    float total=direct+blessingBounce(p.x,p.y,p.z,nx,ny);
    maximum=max(maximum,total);
    if (maximum>BLESSING_MAX_LIGHT) return Float.POSITIVE_INFINITY;
  }
  return maximum;
}

// Lighting is baked before choosing paint locations. No lamps, lightmap values,
// or material visibility rules are changed to accommodate a blessing.
void placeSecrets() {
  secrets.clear();
  if (!giPlacementReady) bakeGI();
  ArrayList<BlessingCandidate> candidates=new ArrayList<BlessingCandidate>();
  for (int i=1;i<GRID-1;i++) for (int j=1;j<GRID-1;j++) {
    if (flow[i][j]<4) continue;
    for (int[] d:DIRS) {
      int ni=i+d[0],nj=j+d[1];
      if (isWall(ni,nj)||!wallBetween(i,j,ni,nj)) continue;
      float light=blessingWallLight(i,j,d[0],d[1]);
      if (Float.isFinite(light)) candidates.add(new BlessingCandidate(i,j,ni,nj,light));
    }
  }
  java.util.Collections.shuffle(candidates);
  java.util.Collections.sort(candidates,new java.util.Comparator<BlessingCandidate>() {
    public int compare(BlessingCandidate a,BlessingCandidate b) {
      int lightOrder=Float.compare(a.light,b.light);
      if (lightOrder!=0) return lightOrder;
      return (flow[a.i][a.j]>SECRET_NEAR?1:0)-(flow[b.i][b.j]>SECRET_NEAR?1:0);
    }
  });
  for (BlessingCandidate c:candidates) {
    if (secrets.size()==SECRETS) break;
    boolean nearby=false;
    for (Secret other:secrets)
      if (abs(other.di-c.i)+abs(other.dj-c.j)<3||secretEdge(c.i,c.j,c.ni,c.nj)) nearby=true;
    if (nearby) continue;
    Secret s=new Secret();s.di=c.i;s.dj=c.j;s.wi=c.ni;s.wj=c.nj;
    s.pizza=!pizzaGot[phase()]&&secrets.isEmpty();secrets.add(s);
  }
  // Fewer optional secrets is preferable to marking a lit wall or creating a
  // conspicuous artificial shadow in an otherwise bright generated level.
}

// paint Cabral's sun on each secret wall, at eye height
void markSecrets() {
  for (Secret s : secrets) {
    Decal dc = new Decal();
    dc.nx = s.di - s.wi;
    dc.ny = s.dj - s.wj;
    dc.cx = (s.di + 0.5) * CELL - dc.nx * (CELL * 0.5 - WALL_THICKNESS / 2 - 2);
    dc.cy = (s.dj + 0.5) * CELL - dc.ny * (CELL * 0.5 - WALL_THICKNESS / 2 - 2);
    dc.z = EYE_H;
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



// a wall face things can hang on (not a secret one: it's going to open)
boolean wallFace(int i, int j, int di, int dj) {
  return !isWall(i, j) && wallBetween(i, j, i + di, j + dj) && !secretEdge(i, j, i + di, j + dj);
}

void updateSecrets(float dt) {
  for (Secret s : secrets) {
    float dcx = (s.di + 0.5) * CELL, dcy = (s.dj + 0.5) * CELL;
    if (!s.opened) {
      // The actual near wall surface, illuminated from the approach side.
      float wx = dcx + (s.wi - s.di) * (CELL * 0.5 - WALL_THICKNESS / 2), wy = dcy + (s.wj - s.dj) * (CELL * 0.5 - WALL_THICKNESS / 2);
      float d = dist(player.x, player.y, wx, wy);
      // Keep the camera aimed at the paint; the short flood must actually reach it.
      float mx = wx + (s.di - s.wi) * 2, my = wy + (s.dj - s.wj) * 2;
      boolean lit = flashlightOn && d < CELL * 2.2 && flashlightAimsAt(mx, my, EYE_H, 0.97);
      s.light = lit ? s.light + dt : max(0, s.light - dt * 2);
      if (lit) staticBurst = max(staticBurst, 0.15 * s.light / REVEAL_TIME);
      if (s.light >= REVEAL_TIME) openSecret(s);
    } else if (s.pizza && !s.eaten && dist(player.x, player.y, (s.wi + 0.5) * CELL, (s.wj + 0.5) * CELL) < 130) {
      eatPizza(s);
    }
  }
}

void openSecret(Secret s) {
  acousticRefresh = 0; // The opened wall changes sound paths immediately.
  s.opened = true;
  decals.remove(s.mark);
  setWallBetween(s.di, s.dj, s.wi, s.wj, false);
  rebuildWallVoxels();
  for (Enemy e : enemies) {
    e.goalFlow = e.navFlow = null;
    e.goalI = e.goalJ = -1;
  }
  level = buildLevel();
  flowI = -1;
  updateFlow();
  queueGIBake(); // Rebuild in short slices while the passage remains playable.
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
    if (!s.opened || !s.pizza || s.eaten) continue;
    float x = (s.wi + 0.5) * CELL, y = (s.wj + 0.5) * CELL;
    float dd = dist(player.x, player.y, x, y);
    if (dd > CELL * 6) continue;
    itemLights(x, y, 125 + sin(t * 2.2) * 10, lerp(1, exp(-pow(dd / FOG_DIST, 1.5)), 0.5));
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
  if (hitsWall(c.x, c.y, CAN_FLOOR + 2)) {    // hugging a wall: start from the body instead
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
  if (hitsWall(nx, c.y, r)) {
    canHit(c, abs(c.vx));
    c.vx *= -0.45;
    c.vy *= 0.8;
    c.tumbleV = -c.tumbleV * 0.7 + random(-4, 4);
  } else {
    c.x = nx;
  }
  float ny = c.y + c.vy * h;
  if (hitsWall(c.x, ny, r)) {
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
    itemLights(c.x, c.y, c.z, lerp(1, exp(-pow(dd / FOG_DIST, 1.5)), 0.5) * 0.7);   // white metal: keep the flashlight from blowing it out
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
// Predict along the actual walkable floor, stopping the player's body before a wall.
int[] predictFrom(float x, float y, float vx, float vy) {
  float sp = sqrt(vx * vx + vy * vy);
  if (sp < 60) return null;
  float ux = vx / sp, uy = vy / sp, reach = min(sp * 1.2, CELL * 3);
  if (!walkableSegment(x, y, x + ux * reach, y + uy * reach, PLAYER_R)) {
    float low = 0, high = reach;
    for (int k = 0; k < 10; k++) {
      float mid = (low + high) * 0.5;
      if (walkableSegment(x, y, x + ux * mid, y + uy * mid, PLAYER_R)) low = mid;
      else high = mid;
    }
    reach = low;
  }
  int i = cellOf(x + ux * reach), j = cellOf(y + uy * reach);
  if (isWall(i, j) || (i == cellOf(x) && j == cellOf(y))) return null;
  return new int[]{i, j};
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
  e.navFlow = null;
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
  int i = cellOf(x0), j = cellOf(y0), ei = cellOf(x1), ej = cellOf(y1);
  if (isWall(i, j) || isWall(ei, ej)) return false;
  float dx = x1 - x0, dy = y1 - y0;
  int sx = dx > 0 ? 1 : dx < 0 ? -1 : 0;
  int sy = dy > 0 ? 1 : dy < 0 ? -1 : 0;
  float tx = sx == 0 ? Float.POSITIVE_INFINITY : (((sx > 0 ? i + 1 : i) * CELL) - x0) / dx;
  float ty = sy == 0 ? Float.POSITIVE_INFINITY : (((sy > 0 ? j + 1 : j) * CELL) - y0) / dy;
  float stepX = sx == 0 ? Float.POSITIVE_INFINITY : CELL / abs(dx);
  float stepY = sy == 0 ? Float.POSITIVE_INFINITY : CELL / abs(dy);
  for (int guard = 0; guard < GRID * 2 + 2; guard++) {
    if (wallRayInCell(i, j, x0, y0, x1, y1)) return false;
    if (i == ei && j == ej) return true;
    if (abs(tx - ty) < 0.000001) {
      if (isWall(i + sx, j) || isWall(i, j + sy)) return false;
      i += sx; j += sy; tx += stepX; ty += stepY;
    } else if (tx < ty) { i += sx; tx += stepX; }
    else { j += sy; ty += stepY; }
    if (isWall(i, j)) return false;
  }
  return false;
}

void setGoal(Enemy e, int gi, int gj) {
  if (gi == e.goalI && gj == e.goalJ && e.goalFlow != null) return;
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
      if (canStep(i, j, ni, nj) && f[ni][nj] < 0) {
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
  // Chase directly over clear floor; sight alone does not guarantee body clearance.
  if (walkableSegment(e.pos.x, e.pos.y, finalPt.x, finalPt.y, ENEMY_RADIUS)) {
    e.navFlow = null;
    return finalPt;
  }
  if (e.navFlow != f || e.navRoute.isEmpty()) buildEnemyRoute(e, f, finalPt);
  while (e.navIndex < e.navRoute.size() && PVector.dist(e.pos, e.navRoute.get(e.navIndex)) < 0.5) e.navIndex++;
  if (e.navIndex >= e.navRoute.size()) return e.pos.copy();
  PVector p = e.navRoute.get(e.navIndex);
  if (!walkableSegment(e.pos.x, e.pos.y, p.x, p.y, ENEMY_RADIUS)) {
    buildEnemyRoute(e, f, finalPt);
    if (e.navRoute.isEmpty()) return e.pos.copy();
    p = e.navRoute.get(0);
  }
  return p;
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
  return p * fixturePower(i, j);
}

void updateLampGrid() {
  java.util.Arrays.fill(mapU, 0);
  java.util.Arrays.fill(wallU, 0);
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    lampP[i][j] = solid[i][j] ? 0 : lampPower(i, j);
    int code = solid[i][j] ? 0 : 1 + round(lampP[i][j] * 15);
    int idx = j * GRID + i;
    mapU[idx / 4] += code * PACK[idx % 4];
    int edges = (hasWallX(i + 1, j) ? 1 : 0) + (hasWallY(i, j + 1) ? 2 : 0);
    wallU[idx / 8] += edges * (1 << (2 * (idx % 8)));
  }
  humLevel = 0;
  float acc = 0;
  int pi = cellOf(player.x), pj = cellOf(player.y);
  for (int i = pi - 1; i <= pi + 1; i++) for (int j = pj - 1; j <= pj + 1; j++) {
    if (isWall(i, j)) continue;
    float dd = dist(player.x, player.y, (i + 0.5) * CELL, (j + 0.5) * CELL);
    humLevel = max(humLevel, lampP[i][j] * constrain(1 - dd / (CELL * 2), 0, 1));
    if (lineOfSight(player.x, player.y, (i + 0.5) * CELL, (j + 0.5) * CELL)) acc += lampP[i][j] * constrain(1 - dd / (CELL * 1.6), 0, 1);
  }
  localLight = constrain(acc * 0.7, 0, 1.2);
  float lit = 0, nominal = 0;
  for (int i = pi - 2; i <= pi + 2; i++) for (int j = pj - 2; j <= pj + 2; j++) {
    if (isWall(i, j) || lampType[i][j] == 2) continue;
    lit += lampP[i][j];
    nominal += (lampType[i][j] == 1 ? 0.7 : 1) * fixturePower(i, j);
  }
  giLive = lerp(giLive, nominal > 0 ? constrain(lit / nominal, 0, 1) : 1, 0.2);
  updateDynamicGI(false);
}



void setVoice(Controller v, float gain, float pan) {
  if (v.hasControl(Controller.GAIN)) v.setGain(gain);
  if (v.hasControl(Controller.PAN)) v.setPan(pan);
  else if (v.hasControl(Controller.BALANCE)) v.setBalance(pan);
}

// =====================================================================
// RENDER
void render() {
  advanceGIBake();
  float dg = danger(threatD);
  float pulse = kickEnv * chaseLvl;
  float dgV = max(dg, chaseLvl * 0.4);
  background(9, 8, 4);

  float ex = camX, ey = camY, ez = camZ;
  float lx = camDX, ly = camDY, lz = camDZ;
  float rx = cameraRightX, ry = cameraRightY;
  float rollR = cameraRoll;

  // the lens pass zooms the center in by 'fe': widen the field of view to keep the same framing
  float aspectR = float(width) / height;
  float fe = 1 + LENS_FISHEYE * 0.25 * (aspectR * aspectR + 1);
  perspective(2 * atan(tan((fov - pulse * radians(2.5)) / 2) * fe), aspectR, 10, CELL * GRID * 1.5);
  camera(ex, ey, ez, ex + lx, ey + ly, ez + lz, rx * sin(rollR), ry * sin(rollR), -cos(rollR));

  for (Enemy e : enemies) {
    PVector sp = lensWarp(screenX(e.pos.x, e.pos.y, 135), screenY(e.pos.x, e.pos.y, 135));
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
  world.set("giMap", giTex);
  world.set("wallGIMap", wallGI);
  world.set("giDynamic", giDynamic);
  world.set("giSize", (float)giSize);
  world.set("giWallSize", (float)giWallSize);
  world.set("wallData", wallU, 4);
  world.set("gridSize", (float) GRID);
  world.set("cellSize", CELL);
  world.set("wallH", WALL_H);
  world.set("wallHalf", WALL_THICKNESS / 2);
  world.set("lampZ", WALL_H - 3);
  world.set("exposure", EXPOSURE_BASE * exposureAdapt);
  world.set("fogDist", FOG_DIST);
  world.set("fogColor", 0.075 * haze, 0.068 * haze, 0.045 * haze);
  world.set("volOn", VOLUMETRIC ? 1.0 : 0.0);
  world.set("wetDebug", SHOW_WET_MASK ? 1.0 : 0.0);
  float fl = flashlightStrength();
  world.set("flash", FLASH_POWER * fl);
  world.set("flashPos", flashPos.x, flashPos.y, flashPos.z);
  world.set("flashDir", flashDir.x, flashDir.y, flashDir.z);
  world.set("flashCol", FLASH_COLOR.x, FLASH_COLOR.y, FLASH_COLOR.z);
  world.set("flashRange", FLASH_RANGE);
  world.set("flashFalloff", FLASH_FALLOFF);
  world.set("flashCone", FLASH_OUTER_COS, FLASH_INNER_COS);
  world.set("emissive", 0.0);

  textureWrap(REPEAT);
  world.set("wallpaper", 1.0);
  drawVisibleLevel(g, xAx, yAx, tan((fov - pulse * radians(2.5)) / 2) * fe, aspectR);
  world.set("wallpaper", 0.0);
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
  meterCamera(g);

  begin2D();
  applyLens();                       // 1. the player's eye: fish-eye, grain, micro-blur
  drawOverlay(dgV, pulse);          // 2. view effects and fade-in
  applyTape();                      // 3. recording signal
  drawCamOsd(dgV);                  // 4. crisp character generator
  applyPost(dgV, spotFlash * 0.5);   // 4. tape faults and camera exposure noise
  drawHUD();                        // 5. gameplay HUD on top
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
  drawPanels(g);
}

// Batch emitters separately from ordinary plastic so each draw uses the right
// shader state. The same path also supports offscreen renderer verification.
void drawPanels(PGraphics target) {
  target.textureWrap(CLAMP);
  target.noStroke();
  world.set("wallpaper",0.0); // preserve diffuser albedo rather than roof.jpg calibration
  int pi=cellOf(player.x),pj=cellOf(player.y);
  float z=WALL_H-2,hw=CELL/12,hh=CELL/12;
  for (int pass=0;pass<2;pass++) {
    world.set("emissive",pass==0?2.4:0.0);
    for (int i=max(0,pi-6);i<=min(GRID-1,pi+6);i++) for (int j=max(0,pj-6);j<=min(GRID-1,pj+6);j++) {
      if (solid[i][j]) continue;
      float p=lampP[i][j];
      boolean dead=p<0.08;
      if (dead!=(pass==1)) continue;
      if (dead) target.tint(232,228,214);
      else {
        float emission=pow(p,1.0/2.2);
        target.tint(lerp(12,255,emission),lerp(11,245,emission),lerp(9,205,emission));
      }
      float cx=(i+0.5)*CELL,cy=(j+0.5)*CELL;
      target.beginShape(QUADS);target.texture(panelTex);
      target.vertex(cx-hw,cy-hh,z,0,0);target.vertex(cx+hw,cy-hh,z,1,0);
      target.vertex(cx+hw,cy+hh,z,1,1);target.vertex(cx-hw,cy+hh,z,0,1);
      target.endShape();
    }
    target.flush(); // uniform changes must not reach geometry queued by the preceding pass
  }
  target.noTint();
}

void drawEnemy(Enemy e) {
  float d = dist(player.x, player.y, e.pos.x, e.pos.y);
  if (d > CELL * 12) return;
  float dg = danger(d);
  boolean stunned = millis() < e.stunUntil;
  float s = 220;
  float base = 25;
  float glitch = stunned ? 35 : 60 * sq(max(dg, chaseLvl * 0.5));
  int strips = 14;

  world.set("emissive", stunned ? 0.6 : 0.18 + 0.25 * dg + 0.15 * chaseLvl);
  textureWrap(CLAMP);
  noStroke();
  if (stunned) tint(130, 180, 255);
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
  post.set("footage", state == PLAYING ? 1.0 : 0.0);
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
// VIEW EFFECTS (before tape); the camcorder character generator follows tape
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

}

// The character generator follows the tape bandwidth filter, before final noise.
void drawCamOsd(float dg) {
  pushStyle(); rectMode(CORNER);
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
  popStyle();
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

  drawEyes(width / 2, 80);

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
      text("SHIFT CORRER   C AGACHAR   1-5 COMER/BEBER   R TASER   G LATA   Q/E NA QUINA ESPREITAR   ESC PAUSA", width / 2, height / 2 - 88);
    }
  }

  drawToasts();
}

// The Eye: shows the most alarming state among the nerdolas (Isa only once she's close)


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
}

void drawInventory() {
  int now = millis();
  syncSlots();
  ArrayList<Integer> shown = new ArrayList<Integer>(slotOrder);
  if (inv[LATA] > 0) shown.add(LATA);
  if (inv[TASER] > 0) shown.add(TASER);
  float slot = 72, sz = 64, y = height - 160;
  int n = shown.size();
  for (int k = 0; k < ITEM_NAMES.length; k++) {
    int idx = shown.indexOf(k);
    boolean on = idx >= 0;
    if (inv[k] > lastInv[k]) slotPop[k] = 1;
    lastInv[k] = inv[k];
    slotPop[k] *= exp(-frameDt * 7);
    if (on) {
      float tx = width / 2 + (idx - (n - 1) / 2.0) * slot;
      if (slotShow[k] < 0.02) slotX[k] = tx;
      slotX[k] = lerp(slotX[k], tx, 1 - exp(-frameDt * 12));
      slotKey[k] = keyFor(k);
    }
    slotShow[k] = lerp(slotShow[k], on ? 1 : 0, 1 - exp(-frameDt * (on ? 10 : 7)));
  }

  rectMode(CENTER);
  imageMode(CENTER);
  for (int k = 0; k < ITEM_NAMES.length; k++) {
    float a = slotShow[k];
    if (a < 0.02) continue;
    float s = sz * (0.6 + 0.4 * a) * (1 + 0.18 * slotPop[k]);
    float x = slotX[k], cy = y + sz / 2 + (1 - a) * 24;
    noStroke();
    fill(0, 215 * a);
    rect(x, cy, s, s);
    stroke(useType == k ? color(200, 30, 20, 255 * a) : color(200, 190, 160, 255 * a));
    strokeWeight(3);
    noFill();
    rect(x, cy, s, s);
    noStroke();
    if (useType == k) {
      float t = constrain((now - useStart) / (float) USE_MS[k], 0, 1);
      fill(200, 30, 20, 200 * a);
      rect(x - s / 2 + s * t / 2, cy + s / 2 - 3, s * t, 4);
    }
    tint(255, 255 * a);
    image(itemTex[k], x, cy + 2, s * 0.78, s * 0.78);
    noTint();
    if (slotKey[k].length() > 0) {
      fill(225, 215, 180, 255 * a);
      rect(x - s / 2 + 8.5, cy - s / 2 + 8.5, 17, 17);
      fill(0, 255 * a);
      textFont(fontMono);
      textSize(12);
      textAlign(CENTER, CENTER);
      text(slotKey[k], x - s / 2 + 8.5, cy - s / 2 + 7.5);
    }
    if (inv[k] > 0) {
      textFont(fontHud);
      textSize(17);
      fill(235, 255 * a);
      textAlign(RIGHT, BOTTOM);
      text("x" + inv[k], x + s / 2 - 4, cy + s / 2 + 1);
    }
  }
  rectMode(CORNER);
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
  //if (k < 1) drawSwitchStatic(width * 0.42, 0, width * 0.58, height, 1 - k);
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
    else drawVsCard(lineX(p), lineY(p), lineS(p), bright, alpha, i == 0, lineupMode == FUGA ? "VS. 6" : "TODOS");
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
  previewLabel(title, hint);
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
    text(itemSeen[k] ? ITEM_DESC[k] + (k == TASER ? "   [R]" : k == LATA ? "   [G]" : "   [SLOT 1-5]") : "Pegue esse item para descobrir o que ele faz.", 180, y + 50);
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
  pauseShot = get();
  releaseKeys();
  peekSide = 0;
  lockMouse(false);
  silenceSynth();
  pauseVoices();
  if (flashSnd != null) flashSnd.stop();
  if (clanks != null) for (AudioSample sample : clanks) sample.stop();
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
  if (msgUntil > 0) msgUntil += d;
  shiftEyeClock(mainEye, d);
  for (Eye e : packEyes) shiftEyeClock(e, d);
  useStart += d;
  if (energyUntil > 0) energyUntil += d;
  if (swiftUntil > 0) swiftUntil += d;
  if (ghostUntil > 0) ghostUntil += d;
  if (fedUntil > 0) fedUntil += d;
  if (pilhadoUntil > 0) pilhadoUntil += d;
  if (fireUntil > 0) fireUntil += d;
  if (flickerUntil > 0) flickerUntil += d;
  lastThrow += d;
  lastStingMs += d;
  toastStart += d;
  for (int k = 0; k < pickupTimes.size(); k++) pickupTimes.set(k, pickupTimes.get(k) + d);
  for (Enemy e : enemies) {
    if (e.lockUntil > 0) e.lockUntil += d;
    if (e.lungeUntil > 0) e.lungeUntil += d;
    if (e.screamUntil > 0) e.screamUntil += d;
    if (e.stunUntil > 0) e.stunUntil += d;
    if (e.confusedUntil > 0) e.confusedUntil += d;
    if (e.nextTeleport > 0) e.nextTeleport += d;
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
  fxBus.setValue(volDb(V_FX));
  voiceBus.setValue(volDb(V_VOICE));
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
    if (kc >= '1' && kc <= '5') useSlot(kc - '1');
    if (kc == 'G') throwCan();
    if (kc == 'Q') startPeek(-1);
    if (kc == 'R') fireTaser();
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

float acousticRefresh;
int acousticFlowI = -1, acousticFlowJ = -1;
// Refresh geometry-dependent routes at 10 Hz; voices and footsteps still smooth every frame.
void refreshAcoustics(float dt) {
  acousticRefresh -= dt;
  if (acousticRefresh <= 0 || acousticFlowI != flowI || acousticFlowJ != flowJ) {
    for (Enemy e : enemies) traceSound(e);
    acousticRefresh = 0.1;
    acousticFlowI = flowI; acousticFlowJ = flowJ;
  }
  for (Enemy e : enemies) if (e.corners == 0) { e.apX = e.pos.x; e.apY = e.pos.y; }
}
void update3DAudio(float dt) {
  refreshAcoustics(dt);
  updateVoices(dt);
  updateEnemySteps(dt);
  updateDistant(dt);
  updateEcho(dt);
  if (ambience.hasControl(Controller.GAIN)) ambience.setGain(volDb(V_AMB) - 10 * chaseLvl);   // the room ducks during a chase
}


void updateVoices(float dt) {
  int now = millis();
  for (Enemy e : enemies) {
    float d = dist(player.x, player.y, e.pos.x, e.pos.y);
    int path = enemyPath(e);
    float heard = path < 999 ? max(d, path * CELL * 0.8) : d;   // volume follows the walking route
    float range = e.ch == T_GUSTAVO ? CELL * 20 : CELL * 14;
    float gain = map(constrain(heard, 0, range), 0, range, 3, -40);
    if (e.ch == T_GUSTAVO) gain += 6;
    if (e.ai != CHASE) gain -= 3;
    if (now < e.screamUntil) gain += 6;
    if (now < e.stunUntil) gain -= 10;
    gain -= 1.5 * e.corners;

    // heard from the opening the sound reaches you through, not through the wall
    float ang = atan2(e.apY - player.y, e.apX - player.x) - yaw;
    float front = cos(ang);
    if (front < 0) gain += 2 * front;                    // a touch quieter behind you

    float cut = CORNER_CUT[min(e.corners, 4)];
    if (now < e.stunUntil) cut = min(cut, 900);

    if (hiddenThreat(e)) gain = -80;
    voices[e.ch].set(min(gain, 6), sin(ang), cut, dt);
  }
}


void updateEnemySteps(float dt) {
  boolean[] used = new boolean[eSteps.length];
  for (Enemy e : enemies) {
    Steps3D s = eSteps[e.ch];
    used[e.ch] = true;
    if (e.speedNow > 20) {
      float before = s.phase;
      s.phase += dt * e.speedNow / 190.0;
      if (floor(s.phase) != floor(before)) s.env = 1;
    }
    s.env *= exp(-dt * 14);
    float d = dist(player.x, player.y, e.pos.x, e.pos.y);
    int path = enemyPath(e);
    float heard = path < 999 ? max(d, path * CELL * 0.8) : d;
    float near = constrain(1 - heard / (CELL * 8), 0, 1);
    float ang = atan2(e.apY - player.y, e.apX - player.x) - yaw;
    float vol = 0.55 * near * near / (1 + 0.25 * e.corners) * (e.ch == T_GUSTAVO ? 1.2 : 1);
    if (hiddenThreat(e)) vol = 0;                        // Isa stays silent
    s.amp.setValue(s.env * vol);
    s.lp.frequency.setLastValue(STEP_CUT[min(e.corners, 4)]);
    s.pan.setPan(constrain(sin(ang), -1, 1));
  }
  for (int k = 0; k < eSteps.length; k++) if (!used[k]) eSteps[k].amp.setValue(0);
}


void updateDistant(float dt) {
  if (distType < 0) {
    if (chaseLvl < 0.3) nextDistant -= dt;
    if (nextDistant > 0) return;
    distType = (int) random(2);
    distT = 0;
    distVol = random(0.5, 1);
    distPan.setPan(random(-0.95, 0.95));
    distO.setWaveform(distType == 1 ? Waves.TRIANGLE : Waves.SINE);
    nextDistant = random(14, 34);
  }
  distT += dt;
  float oa = 0, na = 0, cut = 300, f = 50, end = 1.5;
  if (distType == 0) {             // a heavy door slamming far away
    f = 44 - 10 * min(1, distT);
    oa = 0.45 * exp(-distT * 5);
    na = 0.5 * exp(-distT * 10);
    cut = 280;
    end = 1.2;
  } else {                         // someone running, somewhere
    float ph = (distT / 0.17) % 1;
    na = 0.45 * exp(-ph * 22) * sin(PI * min(1, distT / 2.2));
    cut = 230;
    end = 2.2;
  }
  distO.setFrequency(f);
  distO.setAmplitude(oa * distVol);
  distNAmp.setValue(na * distVol);
  distLP.frequency.setLastValue(cut);
  if (distT > end) {
    distType = -1;
    distO.setAmplitude(0);
    distNAmp.setValue(0);
  }
}


void updateEcho(float dt) {
  int pi = cellOf(player.x), pj = cellOf(player.y), opening = 0;
  for (int i = pi - 2; i <= pi + 2; i++) for (int j = pj - 2; j <= pj + 2; j++) if (!isWall(i, j) && lineOfSight(player.x, player.y, (i + 0.5) * CELL, (j + 0.5) * CELL)) opening++;
  roomOpen = lerp(roomOpen, opening / 25.0, 1 - exp(-dt * 2));
  stepEcho.setDelTime(0.09 + 0.22 * roomOpen);
  stepEcho.setDelAmp(0.2 + 0.35 * roomOpen);
  echoWet.setValue(0.15 + 0.6 * sq(roomOpen));
}


int openNeighbors(int i, int j) {
  int n = 0;
  for (int[] d : DIRS) if (canStep(i, j, i + d[0], j + d[1])) n++;
  return n;
}














void syncSlots() {
  for (int k = slotOrder.size() - 1; k >= 0; k--) {
    int t = slotOrder.get(k);
    if (inv[t] <= 0 && useType != t) slotOrder.remove(k);
  }
  for (int t = 0; t < ITEM_NAMES.length; t++)
    if (t != TASER && t != LATA && (inv[t] > 0 || useType == t) && !slotOrder.contains(t)) slotOrder.add(t);
}


String keyFor(int type) {
  if (type == TASER) return "R";
  if (type == LATA) return "G";
  int i = slotOrder.indexOf(type);
  return i >= 0 ? str(i + 1) : "";
}


void useSlot(int n) {
  syncSlots();
  if (n >= 0 && n < slotOrder.size()) startUse(slotOrder.get(n));
}


final float[] CORNER_CUT = {12000, 5000, 2800, 1800, 1300};
final float[] STEP_CUT = {420, 340, 260, 210, 180};
void traceSound(Enemy e) {
  e.apX = e.pos.x;
  e.apY = e.pos.y;
  e.corners = 0;
  if (lineOfSight(player.x, player.y, e.pos.x, e.pos.y)) return;
  int i = cellOf(e.pos.x), j = cellOf(e.pos.y);
  if (isWall(i, j) || flow[i][j] < 0 || flow[i][j] > 30) {
    e.corners = 4;
    return;
  }
  // the route, enemy first, you last
  ArrayList<PVector> route = new ArrayList<PVector>();
  route.add(new PVector(e.pos.x, e.pos.y));
  int guard = 0;
  while (flow[i][j] > 0 && guard++ < GRID * GRID) {
    int bi = i, bj = j;
    for (int[] d : DIRS) {
      int ni = i + d[0], nj = j + d[1];
      if (canStep(i, j, ni, nj) && flow[ni][nj] == flow[i][j] - 1) {
        bi = ni;
        bj = nj;
        break;
      }
    }
    if (bi == i && bj == j) break;
    i = bi;
    j = bj;
    route.add(new PVector((i + 0.5) * CELL, (j + 0.5) * CELL));
  }
  route.add(new PVector(player.x, player.y));

  // string-pull from your end: every time the line of sight breaks, that's a corner
  float ax = player.x, ay = player.y;
  boolean first = true;
  int k = route.size() - 2;
  while (k >= 0 && e.corners < 4) {
    int last = -1;
    while (k >= 0 && lineOfSight(ax, ay, route.get(k).x, route.get(k).y)) {
      last = k;
      k--;
    }
    if (k < 0) break;                        // the rest of the route is in view
    if (last < 0) {                          // safety: always make progress
      last = k;
      k--;
    }
    PVector c = route.get(last);
    if (first) {                             // the first corner is where you hear it from
      e.apX = c.x;
      e.apY = c.y;
      first = false;
    }
    e.corners++;
    ax = c.x;
    ay = c.y;
  }
}


int eyeModeOf(Enemy e) {
  int now = millis();
  if (survived < graceTime) return 0;
  boolean hidden = hiddenThreat(e);
  if (now < e.stunUntil) return hidden ? 0 : 3;
  if (e.ai == CHASE && e.sees) return 1;
  if (hidden) return 0;
  if (e.ai == CHASE) return 2;
  if (now < e.confusedUntil) return 4;
  if (e.ai == SEARCH) return 5;
  return 0;
}


int eyeModeAll() {
  int best = 0;
  for (Enemy e : enemies) {
    int m = eyeModeOf(e);
    if (EYE_RANK[m] > EYE_RANK[best]) best = m;
  }
  return best;
}


Enemy enemyOf(int ch) {
  for (Enemy e : enemies) if (e.ch == ch) return e;
  return null;
}


void drawEyes(float cx, float cy) {
  float lowest = 30 * EYE_SCALE;
  if (enemies.size() <= 1) {
    renderEye(mainEye, eyeModeAll(), cx, cy, EYE_SCALE, false);
  } else {
    float gap = 18, total = 0;
    int shown = 0;
    for (Enemy e : enemies) {
      Eye ey = packEyes[e.ch];
      int m = eyeModeOf(e);
      boolean on = m == 1 || m == 2 || m == 3 || m == 5;
      ey.show = lerp(ey.show, on ? 1 : 0, 1 - exp(-frameDt * (on ? 9 : 4)));
      float close = constrain(1 - (enemyPath(e) - 1) / 14.0, 0, 1);
      ey.sc = lerp(ey.sc, EYE_SCALE * lerp(0.55, 1.3, close), 1 - exp(-frameDt * 4));
      if (ey.show > 0.02) {
        total += 112 * ey.sc * ey.show + gap;
        shown++;
      }
    }
    if (shown == 0) {
      renderEye(mainEye, 0, cx, cy, EYE_SCALE, true);
    } else {
      float x = cx - (total - gap) / 2;
      for (int ch = 0; ch < 6; ch++) {                 // fixed order: eyes never swap places
        Enemy e = enemyOf(ch);
        if (e == null) continue;
        Eye ey = packEyes[ch];
        if (ey.show <= 0.02) {
          ey.x = -1;
          continue;
        }
        float s = ey.sc * ey.show;
        float tx = x + 56 * s;
        ey.x = ey.x < 0 ? tx : lerp(ey.x, tx, 1 - exp(-frameDt * 8));
        x += 112 * s + gap;
        int m = eyeModeOf(e);
        boolean on = m == 1 || m == 2 || m == 3 || m == 5;
        renderEye(ey, on ? m : 0, ey.x, cy, s, true);
        lowest = max(lowest, 30 * s);
      }
    }
  }

  String sub = "";
  if (crouching) sub = "AGACHADO";
  if (millis() < ghostUntil) sub = sub.length() > 0 ? sub + " / INVISÍVEL" : "INVISÍVEL";
  if (sub.length() > 0) {
    textFont(fontMono);
    textSize(12);
    float tw = textWidth(sub), lb = cy + lowest + 14;
    noStroke();
    fill(0, 170);
    rect(cx - tw / 2 - 8, lb, tw + 16, 20);
    fill(220);
    textAlign(CENTER, CENTER);
    text(sub, cx, lb + 9);
  }
}


void renderEye(Eye ey, int mode, float cx, float cy, float sc, boolean alive) {
  int now = millis();
  boolean hunting = mode == 1;
  float target = 0, lx = 0, ly = 0, shake = 0;
  int iris = color(120);
  boolean veins = false;
  if (mode == 1) {
    target = 1;
    iris = color(190, 15, 10);
    shake = 2.5;
    veins = true;
  } else if (mode == 2) {
    target = 0.8;
    iris = color(190, 80, 15);
    lx = sin(now * 0.005) * 0.35;
    veins = true;
  } else if (mode == 3) {
    target = 0.6;
    iris = color(80, 160, 255);
    lx = cos(now * 0.025) * 0.75;
    ly = sin(now * 0.025) * 0.5;
    shake = 3;
    veins = true;
  } else if (mode == 4) {
    target = 0.45;
    iris = color(110, 150, 210);
    lx = cos(now * 0.004) * 0.8;
    ly = sin(now * 0.0052) * 0.5;
  } else if (mode == 5) {
    target = 0.5;
    iris = color(180, 140, 40);
    lx = ((now / 650) % 2 == 0) ? -0.8 : 0.8;
    ly = ((now / 1300) % 2 == 0) ? 0.2 : -0.1;
  }
  if (target > 0 && now > ey.nextBlink) {
    ey.blinkUntil = now + 120;
    ey.nextBlink = now + (int) random(1600, 4200);
  }
  if (now < ey.blinkUntil && !hunting) target = 0;
  ey.opening = lerp(ey.opening, target, 1 - exp(-frameDt * 16));
  ey.lx = lerp(ey.lx, lx, 1 - exp(-frameDt * 12));
  ey.ly = lerp(ey.ly, ly, 1 - exp(-frameDt * 12));

  // subtle wander + twitches
  float ox = 0, oy = 0, rot = 0;
  if (alive) {
    ox = (noise(ey.seed, now * 0.0005) - 0.5) * 14;
    oy = (noise(ey.seed + 17, now * 0.0005) - 0.5) * 6;
    rot = (noise(ey.seed + 31, now * 0.0004) - 0.5) * 0.08;
    if (now >= ey.twUntil && random(1) < frameDt * (hunting ? 1.8 : 0.6)) {
      ey.twUntil = now + (int) random(45, 130);
      ey.twx = random(-5, 5);
      ey.twy = random(-3, 3);
      ey.twr = random(-0.08, 0.08);
    }
    if (now < ey.twUntil) {
      ox += ey.twx;
      oy += ey.twy;
      rot += ey.twr;
    }
  }

  float w = 112 * sc, h = 30 * sc;
  pushMatrix();
  translate(cx + (ox + random(-shake, shake)) * sc, cy + (oy + random(-shake, shake)) * sc);
  rotate(rot);
  float op = ey.opening * h;
  if (op > 1.5) {
    noStroke();
    fill(hunting ? color(225, 200, 185) : color(200, 195, 180));
    eyeShape(w, op);
    if (veins) {
      stroke(150, 15, 15, 200);
      strokeWeight(1.4 * sc);
      for (int k = 0; k < 6; k++) {
        float side = k < 3 ? -1 : 1;
        float x0 = side * w * 0.46, y0 = (k % 3 - 1) * op * 0.25;
        float x1 = side * w * 0.2, y1 = y0 * 0.4 + (noise(k + ey.seed, now * 0.001) - 0.5) * 6 * sc;
        float mx = (x0 + x1) / 2, my = (y0 + y1) / 2 + (k % 2 == 0 ? 3 : -3) * sc;
        line(x0, y0, mx, my);
        line(mx, my, x1, y1);
      }
      noStroke();
    }
    float r = h * 0.72;
    float ix = ey.lx * w * 0.15, iy = ey.ly * op * 0.3;
    float ih = min(r * 2, op * 1.7);
    fill(iris);
    ellipse(ix, iy, r * 2, ih);
    float pr = hunting ? r * (0.35 + 0.15 * abs(sin(now * 0.02))) : r * 0.75;
    fill(5);
    ellipse(ix, iy, pr, min(pr, ih * 0.9));
    fill(240, 200);
    rect(ix + r * 0.25, iy - ih * 0.3, 4 * sc, 4 * sc);
    noFill();
    stroke(8);
    strokeWeight(5 * sc);
    eyeShape(w, op);
    strokeWeight(3 * sc);
    for (int k = 0; k < 7; k++) {
      float t = (k + 1) / 8.0;
      float x = lerp(-w / 2, w / 2, t);
      float y = -3.9 * op * t * (1 - t);
      line(x, y, x * 1.08, y - 9 * sc);
    }
    noStroke();
  } else {
    noFill();
    for (int pass = 0; pass < 2; pass++) {
      stroke(pass == 0 ? color(10, 200) : color(215, 205, 185));
      strokeWeight((pass == 0 ? 9 : 4) * sc);
      bezier(-w / 2, 0, -w / 4, 10 * sc, w / 4, 10 * sc, w / 2, 0);
      strokeWeight((pass == 0 ? 6 : 2.5) * sc);
      for (int k = 0; k < 7; k++) {
        float t = (k + 1) / 8.0;
        float x = lerp(-w / 2, w / 2, t);
        float y = h * t * (1 - t);
        line(x, y, x * 1.05, y + 9 * sc);
      }
    }
    noStroke();
  }
  popMatrix();
}


void drawVsCard(float x, float y, float sz, float bright, float alpha, boolean front, String title) {
  int now = millis();
  float t = now / 1000.0, b = bright / 255.0;
  boolean tw = now < twitchUntil[6];
  pushMatrix();
  translate(x, y);
  if (tw) {
    translate(twDx[6] * 0.6, twDy[6] * 0.6);
    rotate(twRot[6] * 0.25);
  }
  rectMode(CENTER);
  imageMode(CENTER);
  noStroke();

  // red heartbeat glow
  float beat = pow(abs(sin(t * PI * 0.9)), 6);
  for (int r = 9; r > 0; r--) {
    fill(150 * b, 8, 6, alpha * (0.035 + 0.03 * beat) * (front ? 1 : 0.6));
    ellipse(0, 0, sz * 0.13 * r, sz * 0.13 * r);
  }

  // the six, as photos orbiting slowly
  float R = sz * 0.34, f = sz * 0.27, spin = t * 0.12;
  for (int k = 0; k < 6; k++) {
    float a = -HALF_PI + k * TWO_PI / 6 + spin;
    float lit = 0.45 + 0.55 * noise(k * 3.7, t * 0.7);
    boolean gl = tw && twType[6] == k % 4;
    pushMatrix();
    translate(cos(a) * R + (gl ? random(-7, 7) : 0), sin(a) * R);
    rotate(sin(t * 0.8 + k * 1.1) * 0.06);
    fill(0, alpha * 0.85);
    rect(4, 5, f + 10, f + 10);
    fill(200 * b * lit, 190 * b * lit, 170 * b * lit, alpha);
    rect(0, 0, f + 8, f + 8);
    if (gl) tint(bright * lit, bright * lit * 0.25, bright * lit * 0.25, alpha);
    else tint(bright * lit, alpha);
    image(faces[k], 0, 0, f, f);
    noTint();
    popMatrix();
  }

  rectMode(CORNER);
  imageMode(CORNER);
  popMatrix();
}

void shiftEyeClock(Eye e, int d) {
  if (e == null) return;
  if (e.blinkUntil > 0) e.blinkUntil += d;
  if (e.nextBlink > 0) e.nextBlink += d;
  if (e.twUntil > 0) e.twUntil += d;
}

// Gain has one audio input. Sum independent sources before channel gain.
void initAudioBuses() {
  fxBus = new Gain(0);
  voiceBus = new Gain(0);
  fxMix = new Summer();
  voiceMix = new Summer();
  fxMix.patch(fxBus);
  voiceMix.patch(voiceBus);
}

boolean hasWallX(int i, int j) {
  return wallX != null && i >= 0 && i < wallX.length && j >= 0 && j < wallX[i].length && wallX[i][j];
}
boolean hasWallY(int i, int j) {
  return wallY != null && i >= 0 && i < wallY.length && j >= 0 && j < wallY[i].length && wallY[i][j];
}
boolean wallBetween(int i, int j, int ni, int nj) {
  if (ni != i) return hasWallX(max(i, ni), j);
  return hasWallY(i, max(j, nj));
}
boolean canStep(int i, int j, int ni, int nj) {
  return abs(ni - i) + abs(nj - j) == 1 && !isWall(i, j) && !isWall(ni, nj) && !wallBetween(i, j, ni, nj);
}
boolean circleBox(float x, float y, float r, float x0, float y0, float x1, float y1) {
  return sq(x - constrain(x, x0, x1)) + sq(y - constrain(y, y0, y1)) <= r * r;
}
boolean hitsWallSlab(float x, float y, float r) {
  float half = WALL_THICKNESS / 2;
  int a = max(0, cellOf(x - r - half)), b = min(GRID, cellOf(x + r + half) + 1);
  int c = max(0, cellOf(y - r - half)), d = min(GRID, cellOf(y + r + half) + 1);
  for (int i = a; i <= b; i++) for (int j = c; j <= d; j++) {
    if (hasWallX(i, j) && circleBox(x, y, r, i * CELL - half, j * CELL - half, i * CELL + half, (j + 1) * CELL + half)) return true;
    if (hasWallY(i, j) && circleBox(x, y, r, i * CELL - half, j * CELL - half, (i + 1) * CELL + half, j * CELL + half)) return true;
  }
  return false;
}
boolean segmentBox(float x0, float y0, float x1, float y1, float lx, float ly, float hx, float hy) {
  float low = 0, high = 1, dx = x1 - x0, dy = y1 - y0;
  if (abs(dx) < 0.000001) { if (x0 < lx || x0 > hx) return false; }
  else {
    float a = (lx - x0) / dx, b = (hx - x0) / dx;
    low = max(low, min(a, b)); high = min(high, max(a, b));
    if (low > high) return false;
  }
  if (abs(dy) < 0.000001) { if (y0 < ly || y0 > hy) return false; }
  else {
    float a = (ly - y0) / dy, b = (hy - y0) / dy;
    low = max(low, min(a, b)); high = min(high, max(a, b));
  }
  return low <= high;
}
boolean wallRayInCell(int i, int j, float x0, float y0, float x1, float y1) {
  float h = WALL_THICKNESS / 2;
  for (int side = 0; side <= 1; side++) for (int offset = -1; offset <= 1; offset++) {
    int edge = i + side, along = j + offset;
    if (hasWallX(edge, along) && segmentBox(x0, y0, x1, y1, edge * CELL - h, along * CELL - h, edge * CELL + h, (along + 1) * CELL + h)) return true;
    edge = j + side; along = i + offset;
    if (hasWallY(along, edge) && segmentBox(x0, y0, x1, y1, along * CELL - h, edge * CELL - h, (along + 1) * CELL + h, edge * CELL + h)) return true;
  }
  return false;
}


// An open floor populated by freestanding wall runs and L/T-shaped islands.
// The grid is navigation/light sampling only; no interior cell is a wall block.
void generateWorld() {
  giPlacementReady=false;
  solid = new boolean[GRID][GRID];
  wallX = new boolean[GRID + 1][GRID];
  wallY = new boolean[GRID][GRID + 1];
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++)
    solid[i][j] = i == 0 || j == 0 || i == GRID - 1 || j == GRID - 1;
  for (int k = 1; k < GRID - 1; k++) {
    wallX[1][k] = wallX[GRID - 1][k] = true;
    wallY[k][1] = wallY[k][GRID - 1] = true;
  }
  int target = round(sq(GRID - 2) * 0.42), placed = 0;
  for (int attempt = 0; attempt < target * 20 && placed < target; attempt++) {
    boolean vertical = random(1) < 0.5;
    int i = (int) random(2, GRID - 2), j = (int) random(2, GRID - 2);
    int len = (int) random(2, 6), sign = random(1) < 0.5 ? -1 : 1;
    int gap = len >= 4 && random(1) < 0.32 ? (int) random(1, len - 1) : -1;
    for (int k = 0; k < len; k++) {
      int x = i + (vertical ? 0 : k * sign), y = j + (vertical ? k * sign : 0);
      if (k == gap || x < 2 || y < 2 || x >= GRID - 2 || y >= GRID - 2) continue;
      // Avoid repeated parallel walls a single cell apart: broad bays, not maze lanes.
      if (vertical) {
        if (wallX[x][y] || hasWallX(x - 1, y) || hasWallX(x + 1, y)) continue;
        wallX[x][y] = true;
      } else {
        if (wallY[x][y] || hasWallY(x, y - 1) || hasWallY(x, y + 1)) continue;
        wallY[x][y] = true;
      }
      placed++;
    }
    if (random(1) < 0.45) {
      int x = i + (vertical ? 0 : (len - 1) * sign), y = j + (vertical ? (len - 1) * sign : 0);
      int bend = (int) random(1, 4), turn = random(1) < 0.5 ? -1 : 1;
      for (int k = 0; k < bend; k++) {
        int bx = x + (vertical ? k * turn : 0), by = y + (vertical ? 0 : k * turn);
        if (bx < 2 || by < 2 || bx >= GRID - 2 || by >= GRID - 2) continue;
        if (vertical && !wallY[bx][by] && !hasWallY(bx, by - 1) && !hasWallY(bx, by + 1)) { wallY[bx][by] = true; placed++; }
        if (!vertical && !wallX[bx][by] && !hasWallX(bx - 1, by) && !hasWallX(bx + 1, by)) { wallX[bx][by] = true; placed++; }
      }
    }
  }
  connectOpenFloor();
  rebuildWallVoxels();
}

void setWallBetween(int i, int j, int ni, int nj, boolean value) {
  if (ni != i) wallX[max(i, ni)][j] = value;
  else wallY[i][max(j, nj)] = value;
}

void connectOpenFloor() {
  for (int guard = 0; guard < GRID * GRID; guard++) {
    int[][] reachable = bfs(1, 1);
    boolean disconnected = false, removed = false;
    for (int i = 1; i < GRID - 1; i++) for (int j = 1; j < GRID - 1; j++) {
      if (reachable[i][j] >= 0) continue;
      disconnected = true;
      if (removed) continue;
      for (int[] d : DIRS) {
        int ni = i + d[0], nj = j + d[1];
        if (!isWall(ni, nj) && reachable[ni][nj] >= 0) {
          setWallBetween(i, j, ni, nj, false); removed = true; break;
        }
      }
    }
    if (!disconnected) return;
    if (!removed) throw new IllegalStateException("Could not connect open floor");
  }
  throw new IllegalStateException("Open-floor connectivity repair exceeded limit");
}

boolean secretEdge(int i, int j, int ni, int nj) {
  for (Secret s : secrets) if (!s.opened &&
    ((s.di == i && s.dj == j && s.wi == ni && s.wj == nj) || (s.di == ni && s.dj == nj && s.wi == i && s.wj == j))) return true;
  return false;
}

void rebuildWallVoxels() {
  int n = GRID * WALL_SUBDIV;
  wallVoxels = new boolean[n][n];
  float h = WALL_THICKNESS / 2;
  for (int i = 1; i < GRID; i++) for (int j = 1; j < GRID - 1; j++)
    if (hasWallX(i, j)) fillWallRect(i * CELL - h, j * CELL - h, i * CELL + h, (j + 1) * CELL + h);
  for (int i = 1; i < GRID - 1; i++) for (int j = 1; j < GRID; j++)
    if (hasWallY(i, j)) fillWallRect(i * CELL - h, j * CELL - h, (i + 1) * CELL + h, j * CELL + h);
}

void fillWallRect(float x0, float y0, float x1, float y1) {
  float unit = CELL / WALL_SUBDIV;
  for (int i = max(0, round(x0 / unit)); i < min(wallVoxels.length, round(x1 / unit)); i++)
    for (int j = max(0, round(y0 / unit)); j < min(wallVoxels.length, round(y1 / unit)); j++) wallVoxels[i][j] = true;
}

boolean wallVoxel(int i, int j) {
  return i >= 0 && j >= 0 && i < wallVoxels.length && j < wallVoxels.length && wallVoxels[i][j];
}

// Greedily merge only exposed edges of the solid wall union. L/T/cross joins
// cannot create overlapping coplanar faces, hidden end caps, or junction gaps.
void appendWallMesh(PShape mesh) {
  float unit = CELL / WALL_SUBDIV;
  PVector down = new PVector(0, 0, -WALL_H);
  int n = wallVoxels.length;
  for (int i = 0; i <= n; i++) for (int side = 0; side < 2; side++) {
    int j = 0;
    while (j < n) {
      boolean exposed = side == 0 ? wallVoxel(i, j) && !wallVoxel(i - 1, j) : wallVoxel(i - 1, j) && !wallVoxel(i, j);
      if (!exposed) { j++; continue; }
      int start = j++;
      while (j < n && (side == 0 ? wallVoxel(i, j) && !wallVoxel(i - 1, j) : wallVoxel(i - 1, j) && !wallVoxel(i, j))) j++;
      float length = (j - start) * unit;
      addQuad(mesh, new PVector(i * unit, start * unit, WALL_H), new PVector(0, length, 0), down, length / CELL, WALL_H / CELL);
    }
  }
  for (int j = 0; j <= n; j++) for (int side = 0; side < 2; side++) {
    int i = 0;
    while (i < n) {
      boolean exposed = side == 0 ? wallVoxel(i, j) && !wallVoxel(i, j - 1) : wallVoxel(i, j - 1) && !wallVoxel(i, j);
      if (!exposed) { i++; continue; }
      int start = i++;
      while (i < n && (side == 0 ? wallVoxel(i, j) && !wallVoxel(i, j - 1) : wallVoxel(i, j - 1) && !wallVoxel(i, j))) i++;
      float length = (i - start) * unit;
      addQuad(mesh, new PVector(start * unit, j * unit, WALL_H), new PVector(length, 0, 0), down, length / CELL, WALL_H / CELL);
    }
  }
}

final int LEVEL_CHUNK_CELLS = 4;
class LevelChunk {
  PShape[] material = new PShape[3];
  PShape shape;
  float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE, minZ = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE, maxZ = -Float.MAX_VALUE;
  float x, y, z, radius, distance2;
}
ArrayList<LevelChunk> levelChunks = new ArrayList<LevelChunk>();
HashMap<Integer, LevelChunk> chunkBuild = new HashMap<Integer, LevelChunk>();
boolean buildingLevelChunks;
PShape[] levelMaterials = new PShape[3];
java.util.Comparator<LevelChunk> chunkNearFirst = new java.util.Comparator<LevelChunk>() {
  public int compare(LevelChunk a, LevelChunk b) { return Float.compare(a.distance2, b.distance2); }
};

void beginLevelChunks(PShape floorMesh, PShape ceilingMesh, PShape wallMesh) {
  levelChunks.clear(); chunkBuild.clear();
  levelMaterials[0] = floorMesh; levelMaterials[1] = ceilingMesh; levelMaterials[2] = wallMesh;
  buildingLevelChunks = true;
}

void addChunkQuad(PShape source, PVector o, PVector a, PVector b, float uRep, float vRep) {
  int material = source == levelMaterials[0] ? 0 : source == levelMaterials[1] ? 1 : source == levelMaterials[2] ? 2 : -1;
  if (material < 0) return;
  float chunkSize = CELL * LEVEL_CHUNK_CELLS;
  int ci = floor((o.x + (a.x + b.x) * 0.5) / chunkSize), cj = floor((o.y + (a.y + b.y) * 0.5) / chunkSize);
  int key = ci + cj * (MAX_GRID + 2);
  LevelChunk chunk = chunkBuild.get(key);
  if (chunk == null) { chunk = new LevelChunk(); chunkBuild.put(key, chunk); levelChunks.add(chunk); }
  if (chunk.material[material] == null) chunk.material[material] = startMesh(material == 0 ? carpet : material == 1 ? roof : wall);
  PShape target = chunk.material[material];
  corner(target, o, a, b, 0, 0, uRep, vRep); corner(target, o, a, b, 1, 0, uRep, vRep);
  corner(target, o, a, b, 1, 1, uRep, vRep); corner(target, o, a, b, 0, 1, uRep, vRep);
  float x1 = o.x + a.x + b.x, y1 = o.y + a.y + b.y, z1 = o.z + a.z + b.z;
  chunk.minX = min(chunk.minX, min(o.x, x1)); chunk.maxX = max(chunk.maxX, max(o.x, x1));
  chunk.minY = min(chunk.minY, min(o.y, y1)); chunk.maxY = max(chunk.maxY, max(o.y, y1));
  chunk.minZ = min(chunk.minZ, min(o.z, z1)); chunk.maxZ = max(chunk.maxZ, max(o.z, z1));
}

void finishLevelChunks() {
  buildingLevelChunks = false;
  for (LevelChunk chunk : levelChunks) {
    chunk.shape = createShape(GROUP);
    for (PShape material : chunk.material) if (material != null) { material.endShape(); chunk.shape.addChild(material); }
    chunk.x = (chunk.minX + chunk.maxX) * 0.5; chunk.y = (chunk.minY + chunk.maxY) * 0.5; chunk.z = (chunk.minZ + chunk.maxZ) * 0.5;
    chunk.radius = sqrt(sq(chunk.maxX - chunk.minX) + sq(chunk.maxY - chunk.minY) + sq(chunk.maxZ - chunk.minZ)) * 0.5 + 2;
  }
  chunkBuild.clear();
}

void drawVisibleLevel(PGraphics target, PVector right, PVector up, float tanY, float aspect) {
  if (levelChunks.isEmpty()) { target.shape(level); return; }
  float tanX = tanY * aspect, normalX = sqrt(1 + tanX * tanX), normalY = sqrt(1 + tanY * tanY);
  for (LevelChunk chunk : levelChunks) chunk.distance2 = sq(chunk.x - camX) + sq(chunk.y - camY) + sq(chunk.z - camZ);
  java.util.Collections.sort(levelChunks, chunkNearFirst);
  for (LevelChunk chunk : levelChunks) {
    float dx = chunk.x - camX, dy = chunk.y - camY, dz = chunk.z - camZ;
    float ahead = dx * camDX + dy * camDY + dz * camDZ;
    if (ahead + chunk.radius < 0) continue;
    float across = dx * right.x + dy * right.y + dz * right.z;
    if (abs(across) - ahead * tanX > chunk.radius * normalX) continue;
    float vertical = dx * up.x + dy * up.y + dz * up.z;
    if (abs(vertical) - ahead * tanY > chunk.radius * normalY) continue;
    target.shape(chunk.shape);
  }
}

// A point can see around a corner before a body can fit around it.
// Sweep a circle against the same square-capped slabs used by collision.
final float ENEMY_RADIUS = 35;

float segmentPointDistanceSq(float ax, float ay, float bx, float by, float x, float y) {
  float dx = bx - ax, dy = by - ay, length2 = dx * dx + dy * dy;
  float t = length2 > 0 ? constrain(((x - ax) * dx + (y - ay) * dy) / length2, 0, 1) : 0;
  return sq(x - ax - dx * t) + sq(y - ay - dy * t);
}

boolean sweptCircleBox(float ax, float ay, float bx, float by, float r, float lx, float ly, float hx, float hy) {
  // Rectangle strips plus round corners form the exact circle-expanded box.
  if (segmentBox(ax, ay, bx, by, lx - r, ly, hx + r, hy)
      || segmentBox(ax, ay, bx, by, lx, ly - r, hx, hy + r)) return true;
  float r2 = r * r;
  return segmentPointDistanceSq(ax, ay, bx, by, lx, ly) <= r2
      || segmentPointDistanceSq(ax, ay, bx, by, lx, hy) <= r2
      || segmentPointDistanceSq(ax, ay, bx, by, hx, ly) <= r2
      || segmentPointDistanceSq(ax, ay, bx, by, hx, hy) <= r2;
}

boolean sweptWallsInCell(int i, int j, float ax, float ay, float bx, float by, float r) {
  float h = WALL_THICKNESS / 2;
  for (int side = 0; side <= 1; side++) for (int offset = -1; offset <= 1; offset++) {
    int edge = i + side, along = j + offset;
    if (hasWallX(edge, along) && sweptCircleBox(ax, ay, bx, by, r, edge * CELL - h, along * CELL - h, edge * CELL + h, (along + 1) * CELL + h)) return true;
    edge = j + side; along = i + offset;
    if (hasWallY(along, edge) && sweptCircleBox(ax, ay, bx, by, r, along * CELL - h, edge * CELL - h, (along + 1) * CELL + h, edge * CELL + h)) return true;
  }
  return false;
}

boolean walkableSegment(float ax, float ay, float bx, float by, float r) {
  if (hitsWall(ax, ay, r) || hitsWall(bx, by, r)) return false;
  int i = cellOf(ax), j = cellOf(ay), ei = cellOf(bx), ej = cellOf(by);
  float dx = bx - ax, dy = by - ay;
  int sx = dx > 0 ? 1 : dx < 0 ? -1 : 0, sy = dy > 0 ? 1 : dy < 0 ? -1 : 0;
  float tx = sx == 0 ? Float.POSITIVE_INFINITY : (((sx > 0 ? i + 1 : i) * CELL) - ax) / dx;
  float ty = sy == 0 ? Float.POSITIVE_INFINITY : (((sy > 0 ? j + 1 : j) * CELL) - ay) / dy;
  float stepX = sx == 0 ? Float.POSITIVE_INFINITY : CELL / abs(dx);
  float stepY = sy == 0 ? Float.POSITIVE_INFINITY : CELL / abs(dy);
  for (int guard = 0; guard < GRID * 2 + 2; guard++) {
    if (isWall(i, j) || sweptWallsInCell(i, j, ax, ay, bx, by, r)) return false;
    if (i == ei && j == ej) return true;
    if (abs(tx - ty) < 0.000001) { i += sx; j += sy; tx += stepX; ty += stepY; }
    else if (tx < ty) { i += sx; tx += stepX; }
    else { j += sy; ty += stepY; }
  }
  return false;
}

void buildEnemyRoute(Enemy e, int[][] f, PVector destination) {
  e.navRoute.clear(); e.navIndex = 0; e.navFlow = f;
  int i = cellOf(e.pos.x), j = cellOf(e.pos.y);
  if (f == null || isWall(i, j) || f[i][j] < 0) return;
  ArrayList<PVector> raw = new ArrayList<PVector>();
  raw.add(new PVector((i + 0.5) * CELL, (j + 0.5) * CELL));
  int gi = cellOf(destination.x), gj = cellOf(destination.y);
  for (int guard = 0; f[i][j] > 0 && guard < GRID * GRID; guard++) {
    int bi = i, bj = j;
    float best = Float.MAX_VALUE;
    for (int[] d : DIRS) {
      int ni = i + d[0], nj = j + d[1];
      if (!canStep(i, j, ni, nj) || f[ni][nj] != f[i][j] - 1) continue;
      float score = sq(ni - gi) + sq(nj - gj);
      if (score < best) { bi = ni; bj = nj; best = score; }
    }
    if (bi == i && bj == j) { e.navRoute.clear(); return; }
    i = bi; j = bj;
    raw.add(new PVector((i + 0.5) * CELL, (j + 0.5) * CELL));
  }
  // String-pull once per new flow field, preserving body clearance at every bend.
  float ax = e.pos.x, ay = e.pos.y;
  int first = 0;
  while (first < raw.size()) {
    int last = -1;
    for (int k = first; k < raw.size(); k++) {
      PVector p = raw.get(k);
      if (!walkableSegment(ax, ay, p.x, p.y, ENEMY_RADIUS)) break;
      last = k;
    }
    if (last < 0) { e.navRoute.clear(); return; }
    PVector p = raw.get(last);
    e.navRoute.add(p); ax = p.x; ay = p.y; first = last + 1;
  }
}

void moveEnemy(Enemy e, float dx, float dy) {
  float nx = e.pos.x + dx, ny = e.pos.y + dy;
  if (walkableSegment(e.pos.x, e.pos.y, nx, ny, ENEMY_RADIUS)) { e.pos.set(nx, ny); return; }
  // If a target changes next to a wall, slide only over segments the body can clear.
  if (walkableSegment(e.pos.x, e.pos.y, nx, e.pos.y, ENEMY_RADIUS)) e.pos.x = nx;
  if (walkableSegment(e.pos.x, e.pos.y, e.pos.x, ny, ENEMY_RADIUS)) e.pos.y = ny;
  e.navFlow = null;
}

String[] TAPE_FRAG = {
  "#define PROCESSING_TEXTURE_SHADER",
  "#ifdef GL_ES",
  "precision mediump float;",
  "#endif",
  "uniform sampler2D texture;",
  "uniform vec2 texOffset;",
  "uniform float lumaBlur;",
  "uniform float chromaBlur;",
  "uniform float chromaShift;",
  "uniform float sharpen;",
  "uniform float sat;",
  "varying vec4 vertColor;",
  "varying vec4 vertTexCoord;",
  "vec3 yiq(vec3 c) { return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312))); }",
  "vec3 rgb(vec3 q) { return vec3(q.x + 0.956 * q.y + 0.621 * q.z, q.x - 0.272 * q.y - 0.647 * q.z, q.x - 1.106 * q.y + 1.703 * q.z); }",
  "void main() {",
  "  vec2 uv = vertTexCoord.st;",
  "  float px = texOffset.x;",
  "  float Y = 0.0, Yw = 0.0, wY = 0.0, wW = 0.0;",
  "  for (int k = -6; k <= 6; k++) {",
  "    float fk = float(k);",
  "    float l = yiq(texture2D(texture, uv + vec2(fk * px, 0.0)).rgb).x;",
  "    float gl = exp(-fk * fk / (2.0 * lumaBlur * lumaBlur));",
  "    float gw = exp(-fk * fk / 18.0);",
  "    Y += l * gl; wY += gl;",
  "    Yw += l * gw; wW += gw;",
  "  }",
  "  Y /= wY; Yw /= wW;",
  "  vec2 C = vec2(0.0);",
  "  float wC = 0.0;",
  "  for (int k = -8; k <= 8; k++) {",
  "    float fk = float(k) * 2.0;",
  "    vec2 c = yiq(texture2D(texture, uv + vec2((fk - chromaShift) * px, 0.0)).rgb).yz;",
  "    float g = exp(-fk * fk / (2.0 * chromaBlur * chromaBlur));",
  "    C += c * g; wC += g;",
  "  }",
  "  C /= wC;",
  "  Y += (Y - Yw) * sharpen;",
  "  gl_FragColor = vec4(clamp(rgb(vec3(Y, C * sat)), 0.0, 1.0), 1.0);",
  "}"
};

void applyTape() {
  applyTapeTo(g);
}

// Surface radiosity: cosine-weighted hemisphere transport between the actual
// welded walls, floor and ceiling. Visibility is baked; no per-frame GI rays.
PImage giTex, wallGI, giDynamic;
final int GI_RES = 8, GI_LAYERS = 3, GI_RAYS = 32, GI_BOUNCES = 5;
final float GI_PATCH = CELL / 4;
float giLive = 1;
float[] giField;
int giSize, giWallSize, giFloorSize;
int[] giFloorIds, giWallIds;
ArrayList<LightPatch> giPatches = new ArrayList<LightPatch>();
float[][] giLampWeights;
int giDynamicNext;

class LightPatch {
  float x, y, z, nx, ny, nz, r, g, b;
  float dr, dg, db, ir, ig, ib;
  int[] hits = new int[GI_RAYS];
  LightPatch(float x, float y, float z, float nx, float ny, float nz, float[] rho) {
    this.x=x; this.y=y; this.z=z; this.nx=nx; this.ny=ny; this.nz=nz;
    r=rho[0]; g=rho[1]; b=rho[2];
    java.util.Arrays.fill(hits, -1);
  }
}



float[] averageReflectance(PImage tex, int material) {
  if (material==0) return new float[]{0.13,0.105,0.065};
  float r=0.58, g=0.53, b=0.36;
  if (tex!=null && tex.width>0 && tex.height>0) {
    tex.loadPixels(); r=g=b=0;
    for (int y=0; y<16; y++) for (int x=0; x<16; x++) {
      int c=tex.pixels[min(tex.pixels.length-1, floor((y+0.5)*tex.height/16)*tex.width+floor((x+0.5)*tex.width/16))];
      r+=pow(((c>>16)&255)/255.0,2.2); g+=pow(((c>>8)&255)/255.0,2.2); b+=pow((c&255)/255.0,2.2);
    }
    r/=256; g/=256; b/=256;
  }
  if (material==1) {
    float l=0.299*r+0.587*g+0.114*b;
    float scale=0.42/max(l,0.05);
    r=(l*0.82+r*0.18)*scale*1.08; g=(l*0.82+g*0.18)*scale*1.02; b=(l*0.82+b*0.18)*scale*0.72;
  } else {
    float l=0.299*r+0.587*g+0.114*b, scale=0.6/max(l,0.05);
    r*=scale; g*=scale; b*=scale*0.98;
  }
  return new float[]{constrain(r,0.04,0.82),constrain(g,0.04,0.82),constrain(b,0.04,0.82)};
}

int giWallIndex(int face, int plane, int along, int layer) {
  return ((layer*giWallSize+along)*4+face)*(giWallSize+1)+plane;
}

int addLightPatch(float x,float y,float z,float nx,float ny,float nz,float[] rho) {
  giPatches.add(new LightPatch(x,y,z,nx,ny,nz,rho)); return giPatches.size()-1;
}

void buildLightPatches() {
  giPatches.clear(); giFloorSize=round(GRID*CELL/GI_PATCH);
  giWallSize=GRID*WALL_SUBDIV; giSize=GRID*GI_RES;
  giFloorIds=new int[giFloorSize*giFloorSize*2];
  giWallIds=new int[(giWallSize+1)*giWallSize*4*GI_LAYERS];
  java.util.Arrays.fill(giFloorIds,-1); java.util.Arrays.fill(giWallIds,-1);
  float[] floorRho=averageReflectance(carpet,0), wallRho=averageReflectance(wall,1), ceilingRho=averageReflectance(roof,2);
  for (int y=0;y<giFloorSize;y++) for (int x=0;x<giFloorSize;x++) {
    float px=(x+0.5)*GI_PATCH, py=(y+0.5)*GI_PATCH;
    if (isWall(cellOf(px),cellOf(py))) continue;
    if (hitsWallSlab(px,py,0.01)) {
      boolean found=false;
      for (int k=0;k<4;k++) {
        float qx=px+((k&1)==0?-0.25:0.25)*GI_PATCH, qy=py+((k&2)==0?-0.25:0.25)*GI_PATCH;
        if (!hitsWallSlab(qx,qy,0.01)) { px=qx; py=qy; found=true; break; }
      }
      if (!found) continue;
    }
    int id=y*giFloorSize+x;
    giFloorIds[id]=addLightPatch(px,py,0,0,0,1,floorRho);
    giFloorIds[id+giFloorSize*giFloorSize]=addLightPatch(px,py,WALL_H,0,0,-1,ceilingRho);
  }
  float unit=CELL/WALL_SUBDIV;
  for (int y=0;y<giWallSize;y++) for (int x=0;x<giWallSize;x++) {
    if (!wallVoxel(x,y)) continue;
    for (int face=0;face<4;face++) {
      int nx=face==0?1:face==1?-1:0, ny=face==2?1:face==3?-1:0;
      if (wallVoxel(x+nx,y+ny)) continue;
      float px=(x+0.5+nx*0.5)*unit, py=(y+0.5+ny*0.5)*unit;
      if (isWall(cellOf(px+nx),cellOf(py+ny))) continue;
      int plane=nx!=0?round(px/unit):round(py/unit), along=nx!=0?y:x;
      for (int h=0;h<GI_LAYERS;h++) giWallIds[giWallIndex(face,plane,along,h)]=
        addLightPatch(px,py,(h+0.5)*WALL_H/GI_LAYERS,nx,ny,0,wallRho);
    }
  }
}

// A ray starts just outside a surface. Full-height wall voxels are identical
// to the welded render mesh; traversal stops at the first wall/floor/ceiling.
int traceLightPatch(float ox,float oy,float oz,float dx,float dy,float dz) {
  float unit=CELL/WALL_SUBDIV;
  float end=dz>0.00001?(WALL_H-oz)/dz:dz<-0.00001?-oz/dz:1.0e8;
  int x=floor(ox/unit), y=floor(oy/unit), sx=dx>=0?1:-1, sy=dy>=0?1:-1;
  float tx=abs(dx)<0.00001?1.0e9:((x+(sx>0?1:0))*unit-ox)/dx;
  float ty=abs(dy)<0.00001?1.0e9:((y+(sy>0?1:0))*unit-oy)/dy;
  float stepx=abs(dx)<0.00001?1.0e9:unit/abs(dx), stepy=abs(dy)<0.00001?1.0e9:unit/abs(dy);
  for (int step=0;step<giWallSize*2;step++) {
    float t=min(tx,ty);
    if (t>=end) {
      int fx=floor((ox+dx*end)/GI_PATCH), fy=floor((oy+dy*end)/GI_PATCH);
      if (fx<0||fy<0||fx>=giFloorSize||fy>=giFloorSize) return -1;
      return giFloorIds[(dz>0?giFloorSize*giFloorSize:0)+fy*giFloorSize+fx];
    }
    int face,plane,along;
    if (tx<ty) { x+=sx; face=sx>0?1:0; plane=sx>0?x:x+1; along=floor((oy+dy*t)/unit); tx+=stepx; }
    else { y+=sy; face=sy>0?3:2; plane=sy>0?y:y+1; along=floor((ox+dx*t)/unit); ty+=stepy; }
    if (x<0||y<0||x>=giWallSize||y>=giWallSize) return -1;
    if (wallVoxel(x,y)) {
      int h=constrain(floor((oz+dz*t)*GI_LAYERS/WALL_H),0,GI_LAYERS-1);
      return giWallIds[giWallIndex(face,plane,constrain(along,0,giWallSize-1),h)];
    }
  }
  return -1;
}

void bakePatchDirect(LightPatch s) {
  int ci=cellOf(s.x+s.nx), cj=cellOf(s.y+s.ny);
  float total=0, hr=CELL*1.5;
  if (s.nz < -0.5) {
    // Optical spill around the flush fitting; the downward emitter itself
    // cannot directly illuminate a coplanar ceiling.
    for (int i=max(1,ci-1);i<=min(GRID-2,ci+1);i++) for (int j=max(1,cj-1);j<=min(GRID-2,cj+1);j++) {
      if (lampType[i][j]==2) continue;
      float lx=(i+0.5)*CELL, ly=(j+0.5)*CELL;
      if (!lineOfSight(s.x,s.y,lx,ly)) continue;
      float pd=dist(0,0,max(abs(s.x-lx)-CELL/12,0),max(abs(s.y-ly)-CELL/12,0));
      total+=(lampType[i][j]==1?0.7:1)*fixturePower(i,j)*0.9*exp(-pd/60);
    }
  } else for (int i=max(1,ci-1);i<=min(GRID-2,ci+1);i++) for (int j=max(1,cj-1);j<=min(GRID-2,cj+1);j++) {
    if (lampType[i][j]==2) continue;
    float lx=(i+0.5)*CELL, ly=(j+0.5)*CELL;
    float p=(lampType[i][j]==1?0.7:1)*fixturePower(i,j);
    for (int k=0;k<4;k++) {
      float qx=lx+((k&1)==0?-1:1)*CELL/24, qy=ly+((k&2)==0?-1:1)*CELL/24;
      float dx=qx-s.x, dy=qy-s.y, dz=WALL_H-3-s.z, hd=sqrt(dx*dx+dy*dy);
      if (hd>=hr || !lineOfSight(s.x+s.nx,s.y+s.ny,qx,qy)) continue;
      float d2=dx*dx+dy*dy+dz*dz, inv=1/sqrt(max(d2,1));
      float ndl=max(0,(s.nx*dx+s.ny*dy+s.nz*dz)*inv), sourceCos=max(dz*inv,0);
      float w=1-pow(hd/hr,4), att=w*w/(1+d2/(CELL*CELL*0.9));
      total+=0.25*1.15*0.96*p*att*ndl*sourceCos;
    }
  }
  s.dr=total; s.dg=total*0.98; s.db=total*0.80;
}



int encodeBounce(float r,float g,float b) {
  // Allocate most of the 8-bit precision to the low-energy bounced light.
  int ri=round(constrain(r/(r+0.25),0,1)*255),gi=round(constrain(g/(g+0.25),0,1)*255),bi=round(constrain(b/(b+0.25),0,1)*255);
  return 0xff000000|(ri<<16)|(gi<<8)|bi;
}

// Resample onto a fine, wall-aligned lightmap. Visibility-weighted gathering
// prevents coarse floor patches or bilinear filtering crossing a partition.


void buildDynamicGIWeights() {
  giLampWeights=new float[GRID*GRID][25];
  for (int y=1;y<GRID-1;y++) for (int x=1;x<GRID-1;x++) {
    float px=(x+0.5)*CELL,py=(y+0.5)*CELL;
    for (int dy=-2;dy<=2;dy++) for (int dx=-2;dx<=2;dx++) {
      int i=x+dx,j=y+dy,k=(dy+2)*5+dx+2;
      if (isWall(i,j)||lampType[i][j]==2||!lineOfSight(px,py,(i+0.5)*CELL,(j+0.5)*CELL)) continue;
      giLampWeights[y*GRID+x][k]=1/(1+dx*dx+dy*dy);
    }
  }
  if (giDynamic==null||giDynamic.width!=GRID) giDynamic=createImage(GRID,GRID,RGB);
  giDynamic.loadPixels(); java.util.Arrays.fill(giDynamic.pixels,0xffffffff); giDynamic.updatePixels(); giDynamicNext=0;
}

void updateDynamicGI(boolean reset) {
  if (giDynamic==null||giLampWeights==null) return;
  int now=millis(); if (!reset && now<giDynamicNext) return; giDynamicNext=now+100;
  giDynamic.loadPixels();
  for (int y=0;y<GRID;y++) for (int x=0;x<GRID;x++) {
    float lit=0,nom=0;
    float[] weights=giLampWeights[y*GRID+x];
    for (int dy=-2;dy<=2;dy++) for (int dx=-2;dx<=2;dx++) {
      int i=x+dx,j=y+dy; float w=weights[(dy+2)*5+dx+2]; if (w==0) continue;
      float base=(lampType[i][j]==1?0.7:1)*fixturePower(i,j);
      nom+=w*base; lit+=w*(reset?base:lampP[i][j]);
    }
    float value=nom>0?constrain(lit/nom,0,1):1;
    float old=(giDynamic.pixels[y*GRID+x]&255)/255.0;
    int v=round(255*(reset?value:lerp(old,value,0.55)));
    giDynamic.pixels[y*GRID+x]=0xff000000|(v<<16)|(v<<8)|v;
  }
  giDynamic.updatePixels();
}

// Stable ballast variation creates visible light pools without changing the navigation
// or the fixed-lamp stealth rules. Dynamic flicker still multiplies each fixture.
float fixturePower(int i, int j) {
  int seed = (i * 73856093) ^ (j * 19349663);
  seed = (seed ^ (seed >>> 13)) * 1274126177;
  seed ^= seed >>> 16;
  return (seed & 7) < 3 ? 1.0 : 0.38;
}

// Keep the recording signal at tape resolution; gameplay HUD is drawn afterwards.
PGraphics tapeFrame;
PImage tapeSource, tapeOutput;
final int TAPE_LINES = 480;

// Processing OpenGL cache bridge: version-sensitive. Recheck this and meterCamera
// when upgrading Processing; the bridge avoids a full-frame CPU readback.
void applyTapeTo(PGraphics target) {
  int h = min(TAPE_LINES, target.height), w = max(1, round(target.width * h / float(target.height)));
  if (tapeFrame == null || tapeFrame.width != w || tapeFrame.height != h) {
    if (tapeFrame != null) tapeFrame.dispose();
    tapeFrame = createGraphics(w, h, P2D);
    tapeFrame.smooth(2);
  }
  tape.set("lumaBlur", 0.85);
  tape.set("chromaBlur", 3.2);
  tape.set("chromaShift", 1.0);
  tape.set("sharpen", 0.28);
  tape.set("sat", 1.0);
  // Resolve the active source before changing framebuffers. A plain cached image
  // prevents Processing from trying to copy the new framebuffer as the source.
  processing.opengl.PGraphicsOpenGL source = (processing.opengl.PGraphicsOpenGL)target;
  source.flush();
  processing.opengl.Texture sourceTexture = source.getTexture();
  if (tapeSource == null) { tapeSource = new PImage(); tapeSource.parent = this; tapeSource.format = ARGB; }
  tapeSource.width = tapeSource.pixelWidth = sourceTexture.width;
  tapeSource.height = tapeSource.pixelHeight = sourceTexture.height;
  tapeSource.setModified(false);
  ((processing.opengl.PGraphicsOpenGL)tapeFrame).setCache(tapeSource, sourceTexture);
  tapeFrame.beginDraw();
  tapeFrame.imageMode(CORNER);
  tapeFrame.noTint();
  tapeFrame.blendMode(REPLACE);
  tapeFrame.image(tapeSource, 0, 0, w, h);
  tapeFrame.blendMode(BLEND);
  tapeFrame.filter(tape);
  tapeFrame.endDraw();
  // Restore the caller's viewport, including offscreen render targets.
  source.beginPGL(); source.endPGL();
  processing.opengl.Texture signal = ((processing.opengl.PGraphicsOpenGL)tapeFrame).getTexture(false);
  if (tapeOutput == null) { tapeOutput = new PImage(); tapeOutput.parent = this; tapeOutput.format = ARGB; }
  tapeOutput.width = tapeOutput.pixelWidth = signal.width;
  tapeOutput.height = tapeOutput.pixelHeight = signal.height;
  tapeOutput.setModified(false);
  source.setCache(tapeOutput, signal);
  target.pushStyle();
  target.imageMode(CORNER);
  target.noTint();
  target.image(tapeOutput, 0, 0, target.width, target.height);
  target.popStyle();
}

// New runs bake once while loading. Opened passages rebuild in small main-thread
// slices, retaining complete lightmaps until both replacement atlases are ready.
SurfaceBake surfaceBake;
boolean giBakeQueued;

void bakeGI() {
  giBakeQueued=false;
  SurfaceBake job=new SurfaceBake(); surfaceBake=null;
  while (!job.done) job.advance(Long.MAX_VALUE);
}

void queueGIBake() { giBakeQueued=true; }

void advanceGIBake() {
  if (giBakeQueued) { giBakeQueued=false; surfaceBake=new SurfaceBake(); }
  if (surfaceBake==null) return;
  surfaceBake.advance(System.nanoTime()+2000000L);
  if (surfaceBake.done) surfaceBake=null;
}

class SurfaceBake {
  int stage, cursor, bounce, count;
  float[] redL,greenL,blueL,nr,ng,nb,nextField;
  int[] floorPixels,wallPixels;
  boolean done;
  SurfaceBake() {
    buildLightPatches(); count=giPatches.size();
    redL=new float[count]; greenL=new float[count]; blueL=new float[count];
    nr=new float[count]; ng=new float[count]; nb=new float[count];
    floorPixels=new int[giSize*giSize*2]; wallPixels=new int[giWallIds.length]; nextField=new float[giSize*giSize];
    java.util.Arrays.fill(floorPixels,0xff000000); java.util.Arrays.fill(wallPixels,0xff000000);
  }
  void advance(long deadline) {
    while (!done && System.nanoTime()<deadline) {
      if (stage==0) {
        int end=min(count,cursor+16);
        for (;cursor<end;cursor++) {
          LightPatch s=giPatches.get(cursor); bakePatchDirect(s);
          float rotation=((cursor*0.61803398875)%1)*TWO_PI;
          for (int k=0;k<GI_RAYS;k++) {
            float r=sqrt((k+0.5)/GI_RAYS),theta=k*2.39996323+rotation;
            float u=r*cos(theta),v=r*sin(theta),w=sqrt(max(0,1-r*r));
            float dx,dy,dz;
            if (s.nz!=0) { dx=u;dy=v;dz=w*s.nz; }
            else { dx=w*s.nx-u*s.ny;dy=w*s.ny+u*s.nx;dz=v; }
            s.hits[k]=traceLightPatch(s.x+s.nx*0.75,s.y+s.ny*0.75,s.z+s.nz*0.75,dx,dy,dz);
          }
          redL[cursor]=s.dr*s.r; greenL[cursor]=s.dg*s.g; blueL[cursor]=s.db*s.b;
        }
        if (cursor==count) { cursor=0;stage=1; }
      } else if (stage==1) {
        int end=min(count,cursor+128);
        for (;cursor<end;cursor++) {
          LightPatch s=giPatches.get(cursor);float r=0,g=0,b=0;
          for (int hit:s.hits) if (hit>=0) { r+=redL[hit];g+=greenL[hit];b+=blueL[hit]; }
          s.ir=r/GI_RAYS;s.ig=g/GI_RAYS;s.ib=b/GI_RAYS;
          nr[cursor]=s.r*(s.dr+s.ir);ng[cursor]=s.g*(s.dg+s.ig);nb[cursor]=s.b*(s.db+s.ib);
        }
        if (cursor==count) {
          float[] swap=redL;redL=nr;nr=swap;swap=greenL;greenL=ng;ng=swap;swap=blueL;blueL=nb;nb=swap;
          cursor=0;if (++bounce==GI_BOUNCES) stage=2;
        }
      } else if (stage==2) {
        int total=giSize*giSize,end=min(total,cursor+16);
        for (;cursor<end;cursor++) {
          int x=cursor%giSize,y=cursor/giSize;
          floorPixels[cursor]=floorBouncePixel(x,y,0,nextField);
          floorPixels[cursor+total]=floorBouncePixel(x,y,1,nextField);
        }
        if (cursor==total) { cursor=0;stage=3; }
      } else if (stage==3) {
        int end=min(wallPixels.length,cursor+512);
        for (;cursor<end;cursor++) wallPixels[cursor]=wallBouncePixel(cursor);
        if (cursor==wallPixels.length) { cursor=0;stage=4; }
      } else {
        // Commit only finished maps; shader readers never see half-built data.
        if (giTex==null||giTex.width!=giSize) giTex=createImage(giSize,giSize*2,RGB);
        giTex.loadPixels();arrayCopy(floorPixels,giTex.pixels);giTex.updatePixels();
        int width=4*(giWallSize+1),height=giWallSize*GI_LAYERS;
        if (wallGI==null||wallGI.width!=width) wallGI=createImage(width,height,RGB);
        wallGI.loadPixels();arrayCopy(wallPixels,wallGI.pixels);wallGI.updatePixels();
        giField=nextField;buildDynamicGIWeights();updateDynamicGI(true);giPlacementReady=true;done=true;
      }
    }
  }
}

int floorBouncePixel(int x,int y,int face,float[] field) {
  float unit=CELL/GI_RES,px=(x+0.5)*unit,py=(y+0.5)*unit;
  if (isWall(cellOf(px),cellOf(py))||hitsWallSlab(px,py,0.01)) return 0xff000000;
  int cx=floor(px/GI_PATCH),cy=floor(py/GI_PATCH);
  float r=0,g=0,b=0,weight=0;
  for (int yy=max(0,cy-1);yy<=min(giFloorSize-1,cy+1);yy++) for (int xx=max(0,cx-1);xx<=min(giFloorSize-1,cx+1);xx++) {
    int id=giFloorIds[face*giFloorSize*giFloorSize+yy*giFloorSize+xx];if (id<0) continue;
    LightPatch p=giPatches.get(id);
    float w=max(0,1-abs(px-p.x)/(GI_PATCH*1.25))*max(0,1-abs(py-p.y)/(GI_PATCH*1.25));
    if (w<=0||!lineOfSight(px,py,p.x,p.y)) continue;
    r+=p.ir*w;g+=p.ig*w;b+=p.ib*w;weight+=w;
  }
  if (weight>0) { r/=weight;g/=weight;b/=weight; }
  if (face==0) field[y*giSize+x]=0.299*r+0.587*g+0.114*b;
  return encodeBounce(r,g,b);
}

int wallBouncePixel(int id) {
  if (giWallIds[id]<0) return 0xff000000;
  LightPatch p=giPatches.get(giWallIds[id]);
  int plane=id%(giWallSize+1),q=id/(giWallSize+1),face=q%4;
  q/=4;int along=q%giWallSize,h=q/giWallSize;
  float r=p.ir*4,g=p.ig*4,b=p.ib*4,w=4;
  for (int d=-1;d<=1;d+=2) {
    if (along+d>=0&&along+d<giWallSize) {
      int neighbor=giWallIds[giWallIndex(face,plane,along+d,h)];
      if (neighbor>=0) { LightPatch v=giPatches.get(neighbor);r+=v.ir;g+=v.ig;b+=v.ib;w++; }
    }
    if (h+d>=0&&h+d<GI_LAYERS) {
      int neighbor=giWallIds[giWallIndex(face,plane,along,h+d)];
      if (neighbor>=0) { LightPatch v=giPatches.get(neighbor);r+=v.ir;g+=v.ig;b+=v.ib;w++; }
    }
  }
  return encodeBounce(r/w,g/w,b/w);
}

// Meter only the rendered world, before lens/tape/OSD. The tiny GPU reduction
// reads 48 luminance samples at 8 Hz, not a full-resolution CPU screenshot.
PGraphics meterFrame;
PImage meterSource;
PShader meterShader;
int meterNext;
float cameraExposureTarget = 1;

String[] METER_FRAG = {
  "#define PROCESSING_TEXTURE_SHADER",
  "#ifdef GL_ES",
  "precision highp float;",
  "#endif",
  "uniform sampler2D texture;",
  "uniform float appliedExposure;",
  "varying vec4 vertTexCoord;",
  "void main() {",
  "  vec2 tile = floor(vertTexCoord.st * vec2(8.0, 6.0));",
  "  float result = 0.0;",
  "  for (int y=0; y<4; y++) for (int x=0; x<4; x++) {",
  "    vec2 uv = (tile + (vec2(float(x),float(y)) + 0.5)/4.0) / vec2(8.0,6.0);",
  "    vec3 signal = pow(texture2D(texture, uv).rgb, vec3(2.2));",
  "    vec3 linear = -log(max(vec3(1.0)-signal, vec3(0.005))) / max(appliedExposure*1.6, 0.01);",
  "    float luminance = dot(linear, vec3(0.2126,0.7152,0.0722));",
  "    result += clamp((log2(max(luminance,0.00024414)) + 12.0)/16.0,0.0,1.0);",
  "  }",
  "  gl_FragColor=vec4(vec3(result/16.0),1.0);",
  "}"
};

// Uses the same version-sensitive OpenGL texture-cache bridge as applyTapeTo.
void meterCamera(PGraphics target) {
  int now=millis(); if (now<meterNext) return; meterNext=now+125;
  if (meterFrame==null) {
    meterFrame=createGraphics(8,6,P2D); meterFrame.noSmooth();
    meterShader=new PShader(this,POST_VERT,METER_FRAG);
  }
  processing.opengl.PGraphicsOpenGL source=(processing.opengl.PGraphicsOpenGL)target;
  source.flush(); processing.opengl.Texture signal=source.getTexture();
  if (meterSource==null) { meterSource=new PImage(); meterSource.parent=this; meterSource.format=ARGB; }
  meterSource.width=meterSource.pixelWidth=signal.width; meterSource.height=meterSource.pixelHeight=signal.height;
  meterSource.setModified(false); ((processing.opengl.PGraphicsOpenGL)meterFrame).setCache(meterSource,signal);
  meterShader.set("appliedExposure",EXPOSURE_BASE*exposureAdapt);
  meterFrame.beginDraw(); meterFrame.imageMode(CORNER); meterFrame.noTint(); meterFrame.blendMode(REPLACE);
  meterFrame.shader(meterShader); meterFrame.image(meterSource,0,0,8,6); meterFrame.resetShader(); meterFrame.endDraw();
  meterFrame.loadPixels(); source.beginPGL(); source.endPGL();
  cameraExposureTarget=exposureFromMeter(meterFrame.pixels);
}

float exposureFromMeter(int[] pixels) {
  float[] values=new float[48];
  for (int i=0;i<48;i++) values[i]=((pixels[i]>>16)&255)/255.0*16-12;
  float[] sorted=values.clone(); java.util.Arrays.sort(sorted);
  float sum=0,weights=0,lo=sorted[2],hi=sorted[43];
  for (int y=0;y<6;y++) for (int x=0;x<8;x++) {
    float w=1-0.5*constrain(sq((x-3.5)/4)+sq((y-2.5)/3),0,1);
    sum+=constrain(values[y*8+x],lo,hi)*w; weights+=w;
  }
  float sceneLuma=pow(2,sum/weights);
  // A bounded camcorder gain preserves dark rooms instead of normalizing them
  // to daylight. Real meter input makes looking into a bright bay matter.
  return constrain(0.23/max(sceneLuma,0.01),0.72,1.65);
}
