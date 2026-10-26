import '../media/media_store.dart';

class ProgramSeed {
  final String name;
  final String goal; // 'gain' or 'lose'
  final String intensity; // 'low', 'medium' or 'high'
  final int weeks;
  final int minutes;
  final String description;
  final List<String> days; // exactly 7 entries, Monday first

  const ProgramSeed({
    required this.name,
    required this.goal,
    required this.intensity,
    required this.weeks,
    required this.minutes,
    required this.description,
    required this.days,
  });

  /// Any supported image type: gif, png, jpg, jpeg or webp. Null if none is bundled.
  String? get mediaPath => findBundledImage('assets/programs', slugOf(name));
}

// Day templates: "Title|Exercise:setsxreps|...". 'Rest' is a rest day.
const _rest = 'Rest';
const _chest = 'Chest|Bench Press:4x8|Incline Dumbbell Press:3x10|Cable Fly:3x12';
const _chestLight = 'Chest|Push-up:3x15|Pec Deck:3x12|Dumbbell Fly:3x12';
const _back = 'Back|Lat Pulldown:4x10|Seated Cable Row:3x12|Dumbbell Pullover:3x12';
const _backLight = 'Back|Chest-Supported Row:3x12|Straight-Arm Pulldown:3x12|Back Extension:3x15';
const _legs = 'Legs|Back Squat:4x8|Leg Press:3x12|Lying Leg Curl:3x12|Calf Raise:4x15';
const _legsLight = 'Legs|Goblet Squat:3x12|Walking Lunge:3x12|Leg Extension:3x12';
const _shoulders = 'Shoulders|Overhead Barbell Press:4x8|Dumbbell Lateral Raise:3x12|Face Pull:3x15';
const _shouldersLight = 'Shoulders|Seated Dumbbell Press:3x10|Cable Lateral Raise:3x12|Reverse Pec Deck:3x12';
const _arms = 'Arms|Barbell Curl:3x10|Triceps Pushdown:3x12|Dumbbell Hammer Curl:3x12|Overhead Triceps Extension:3x12';
const _armsLight = 'Arms|Cable Curl:3x12|Concentration Curl:3x10|Triceps Pushdown:3x12';
const _glutes = 'Glutes|Hip Thrust:4x10|Cable Kickback:3x12|Glute Kickback Machine:3x12';
const _glutesLight = 'Glutes|Glute Bridge:3x15|Step-Up:3x10|Resistance Band Lateral Walk:3x15';
const _coreLight = 'Core|Dead Bug:3x10|Side Plank:3x10|Bicycle Crunch:3x15';
const _coreBurn = 'Core|Mountain Climber:3x20|Russian Twist:3x20|Side Plank:3x10';
const _cardioA = 'Cardio|Jumping Jacks:3x30|High Knees:3x30|Jump Rope:3x30';
const _cardioB = 'Cardio|Rowing Machine:3x10|Stair Climber:3x15|Battle Ropes:3x30';
const _hiit = 'Cardio|Burpee:4x12|Jumping Jacks:4x40|Battle Ropes:4x30';
const _fullGain = 'Chest + Back|Push-up:3x12|Lat Pulldown:3x12|Dumbbell Pullover:3x12';
const _fullLose = 'Legs + Glutes|Goblet Squat:3x12|Glute Bridge:3x15|Step-Up:3x10';

const programDataset = <ProgramSeed>[
  // ---------- GAIN WEIGHT ----------
  ProgramSeed(
    name: 'Beginner Mass Foundation', goal: 'gain', intensity: 'low',
    weeks: 8, minutes: 45,
    description: 'Three simple full-effort days to learn the lifts and start adding muscle.',
    days: [_chestLight, _rest, _backLight, _rest, _legsLight, _rest, _rest],
  ),
  ProgramSeed(
    name: 'Full Body Starter', goal: 'gain', intensity: 'low',
    weeks: 8, minutes: 50,
    description: 'Balanced whole-body sessions for beginners who train three days a week.',
    days: [_fullGain, _rest, _armsLight, _rest, _legsLight, _rest, _rest],
  ),
  ProgramSeed(
    name: 'Strength Base', goal: 'gain', intensity: 'low',
    weeks: 10, minutes: 50,
    description: 'Build a strength base with light weights and steady progression.',
    days: [_chestLight, _rest, _backLight, _rest, _legsLight, _shouldersLight, _rest],
  ),
  ProgramSeed(
    name: 'Upper Lower Split', goal: 'gain', intensity: 'medium',
    weeks: 8, minutes: 60,
    description: 'Four upper and lower sessions per week for steady muscle growth.',
    days: [_chest, _back, _rest, _legs, _rest, _shoulders, _arms],
  ),
  ProgramSeed(
    name: 'Push Pull Legs', goal: 'gain', intensity: 'medium',
    weeks: 8, minutes: 65,
    description: 'Classic three-way split that trains every muscle twice a week.',
    days: [_chest, _back, _legs, _rest, _shoulders, _arms, _rest],
  ),
  ProgramSeed(
    name: 'Strength Hypertrophy', goal: 'gain', intensity: 'medium',
    weeks: 10, minutes: 70,
    description: 'Heavier compound lifts combined with accessory work for size.',
    days: [_legs, _rest, _chest, _back, _rest, _shoulders, _arms],
  ),
  ProgramSeed(
    name: 'Advanced Hypertrophy', goal: 'gain', intensity: 'high',
    weeks: 12, minutes: 75,
    description: 'High-volume training for experienced lifters who want maximum growth.',
    days: [_legs, _chest, _rest, _back, _shoulders, _arms, _rest],
  ),
  ProgramSeed(
    name: 'Power Split', goal: 'gain', intensity: 'high',
    weeks: 12, minutes: 80,
    description: 'Heavy strength work on the main lifts, followed by volume sets.',
    days: [_chest, _legs, _rest, _back, _rest, _shoulders, _arms],
  ),
  ProgramSeed(
    name: 'Peak Mass Program', goal: 'gain', intensity: 'high',
    weeks: 12, minutes: 80,
    description: 'A six-day plan for athletes aiming for their biggest physique.',
    days: [_legs, _chest, _back, _rest, _shoulders, _arms, _glutes],
  ),

  // ---------- LOSE WEIGHT ----------
  ProgramSeed(
    name: 'Walk and Tone', goal: 'lose', intensity: 'low',
    weeks: 6, minutes: 30,
    description: 'Gentle cardio and light toning to start burning calories without strain.',
    days: [_cardioA, _rest, _coreLight, _rest, _legsLight, _rest, _rest],
  ),
  ProgramSeed(
    name: 'Beginner Burn Start', goal: 'lose', intensity: 'low',
    weeks: 6, minutes: 40,
    description: 'Short cardio sessions with simple strength work to build the habit.',
    days: [_cardioA, _rest, _shouldersLight, _rest, _glutesLight, _rest, _rest],
  ),
  ProgramSeed(
    name: 'Gentle Lean Circuit', goal: 'lose', intensity: 'low',
    weeks: 8, minutes: 40,
    description: 'A full-body circuit with plenty of rest between sessions.',
    days: [_fullLose, _rest, _cardioA, _rest, _coreLight, _rest, _rest],
  ),
  ProgramSeed(
    name: 'Fat Burn Circuit', goal: 'lose', intensity: 'medium',
    weeks: 8, minutes: 45,
    description: 'Mixed cardio and upper-body circuits to raise daily energy use.',
    days: [_cardioB, _rest, _chestLight, _cardioA, _rest, _backLight, _rest],
  ),
  ProgramSeed(
    name: 'Cardio Strength Mix', goal: 'lose', intensity: 'medium',
    weeks: 8, minutes: 50,
    description: 'Alternates strength sessions with cardio to keep muscle while losing fat.',
    days: [_cardioB, _armsLight, _rest, _legsLight, _cardioA, _rest, _coreBurn],
  ),
  ProgramSeed(
    name: 'Lean Builder', goal: 'lose', intensity: 'medium',
    weeks: 10, minutes: 50,
    description: 'Strength days with short cardio finishers for a leaner look.',
    days: [_chestLight, _cardioA, _rest, _backLight, _legsLight, _rest, _coreBurn],
  ),
  ProgramSeed(
    name: 'HIIT Shred', goal: 'lose', intensity: 'high',
    weeks: 8, minutes: 40,
    description: 'Short high-intensity intervals with two rest days each week.',
    days: [_hiit, _rest, _legsLight, _hiit, _rest, _coreBurn, _hiit],
  ),
  ProgramSeed(
    name: 'Intense Fat Burn', goal: 'lose', intensity: 'high',
    weeks: 10, minutes: 50,
    description: 'Hard conditioning sessions for experienced trainees.',
    days: [_hiit, _chest, _cardioB, _rest, _legsLight, _coreBurn, _rest],
  ),
  ProgramSeed(
    name: 'Metabolic Conditioning', goal: 'lose', intensity: 'high',
    weeks: 10, minutes: 55,
    description: 'Full-body metabolic training designed for maximum calorie burn.',
    days: [_cardioB, _hiit, _rest, _fullLose, _rest, _coreBurn, _hiit],
  ),
];