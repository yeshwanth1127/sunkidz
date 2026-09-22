export const contact = {
  phones: ["+91 9972277588", "+91 9980547804"],
  phoneTel: "+919972277588",
  whatsapp: "919972277588",
  email: "sunkidzpreschool@gmail.com",
};

export const tagline = "Making child's life a celebration";

export const brandLine = "Preschool, daycare & joyful learning in Bangalore";

export const brandSupport =
  "A safe, colorful place where children explore, create, and grow with confidence.";

export type PillarExample = {
  title: string;
  icon: string;
  intro?: string;
  tags: string[];
  points: string[];
  quote: string;
};

export type Pillar = {
  id: string;
  code: string;
  title: string;
  icon: string;
  color: "sky" | "leaf" | "coral" | "sun";
  summary: string;
  detail: string;
  examples?: PillarExample[];
};

export const pillars: Pillar[] = [
  {
    id: "telm",
    code: "T.E.L.M",
    title: "Experiential Learning Methodology",
    icon: "🔬",
    color: "sky",
    summary:
      "Hands-on discovery—colors, letters, and everyday skills come alive through play.",
    detail:
      "Children are naturally drawn to color, texture, and everyday objects. At SunKidz, we channel that curiosity into hands-on activities that build visual awareness, decision-making, coordination, and independence.",
    examples: [
      {
        title: "Color Creation",
        icon: "🎨",
        tags: ["Mixing colors", "Safe paints & dyes", "Visual awareness", "Fine motor skills"],
        points: [
          "Through mixing primary colors, children learn how new shades are formed",
          "Safe, washable materials such as finger paints, colored water, and natural dyes are used",
          "Activities are designed to develop visual awareness, decision-making, and creative thinking",
          "This hands-on activity also enhances fine motor control and sensory exploration",
        ],
        quote:
          "Every child becomes a little scientist, discovering colors in their own magical way.",
      },
      {
        title: "Latch Closing and Opening",
        icon: "🔐",
        intro: "Practical life skills are an important part of learning at SunKidz.",
        tags: ["Latches & zippers", "Hand-eye coordination", "Confidence", "Self-help skills"],
        points: [
          "Children engage with everyday objects like latches, zippers, buttons, and locks in a safe setup",
          "These tasks improve hand-eye coordination, grip strength, and problem-solving",
          "Helps children gain confidence and independence as they master everyday tasks",
          "Builds a strong foundation for self-help skills and logical thinking",
        ],
        quote: "Tiny hands mastering big skills – one latch at a time.",
      },
    ],
  },
  {
    id: "tlsd",
    code: "T.L.S.D",
    title: "Leadership & Social Development",
    icon: "🤝",
    color: "leaf",
    summary:
      "Kindness, empathy, and teamwork—skills that shape confident little citizens.",
    detail:
      "Children begin to understand themselves and others through guided role-based play and real-world experiences—learning to lead gently, listen closely, and speak with confidence.",
    examples: [
      {
        title: "Role Explanation",
        icon: "🎭",
        intro:
          "Children begin to understand themselves and others through guided role-based play and real-world experiences.",
        tags: ["Community helpers", "Dress-up play", "Empathy"],
        points: [
          "Understanding Community Helpers—children learn about doctors, teachers, firefighters, and more, discovering how everyone plays a part in society",
          "Dramatic Role Play—through dress-up and pretend play, children explore different roles, responsibilities, and perspectives",
          "Building Empathy—taking on roles helps children develop compassion, patience, and the ability to see from others' viewpoints",
        ],
        quote: "When children play a role, they learn the value of every soul.",
      },
      {
        title: "Stories and Dialogues",
        icon: "📖",
        intro:
          "We bring words to life through stories and conversations that nurture emotional intelligence and imagination.",
        tags: ["Daily storytelling", "Discussions", "Morals & fables", "Vocabulary"],
        points: [
          "Interactive Storytelling—daily story sessions spark curiosity, improve attention, and strengthen listening skills",
          "Dialogues & Discussions—guided conversations encourage children to share opinions, ask questions, and communicate clearly",
          "Moral Development—fables and folktales introduce children to concepts like kindness, fairness, honesty, and cooperation",
          "Language Growth—engaging with stories expands vocabulary and builds strong foundations for reading and writing",
        ],
        quote: "A well-told story shapes not just the mind — but the heart.",
      },
      {
        title: "Stage Presentation",
        icon: "🎤",
        intro: "We give every child a stage—because every voice deserves to be heard.",
        tags: ["Confidence", "Teamwork", "Music & drama", "Annual day"],
        points: [
          "Confidence Building—from simple rhymes to full performances, children develop courage and self-expression in front of others",
          "Team Participation—group performances help children learn timing, turn-taking, and group responsibility",
          "Creative Expression—music, drama, dance, and speech are mediums for children to express themselves artistically and emotionally",
          "Celebration of Talent—events and annual days provide platforms for children to showcase their unique skills and growth",
        ],
        quote: "A child who steps onto the stage, steps into confidence for life.",
      },
    ],
  },
  {
    id: "hwms",
    code: "H.W.M.S",
    title: "Holistic Wellness & Self-Defence",
    icon: "💪",
    color: "coral",
    summary:
      "Movement, mindfulness, and body awareness for healthy, resilient kids.",
    detail:
      "Wellness at SunKidz means healthy habits, joyful nutrition, and daily movement—woven into everyday routines so children grow strong, aware, and resilient.",
    examples: [
      {
        title: "Hydration",
        icon: "💧",
        intro: "We make hydration a fun and routine part of every child's day.",
        tags: ["Healthy habits", "Water stations", "Fun reminders", "Water Bottle Day"],
        points: [
          "Healthy Habits—children are encouraged to sip water regularly, especially after activities and during meals",
          "Hydration Corners—kid-friendly water stations are placed throughout the environment for easy, independent access",
          "Learning Moments—children are introduced to the importance of water for energy, brain power, and overall health",
          "Visual Reminders—fun posters and gentle cues remind children to drink water often",
          "Hydration Celebrations—themed days like “Water Bottle Day” make drinking water exciting and enjoyable",
        ],
        quote: "A sip of water may be small, but it fuels great adventures.",
      },
      {
        title: "Nutrition Months: Fruit Month & Millet Month",
        icon: "🍎",
        intro:
          "Nutrition is explored through taste, touch, storytelling, and creativity during our special monthly themes.",
        tags: ["Tasting sessions", "Sensory play", "Fruit & millet facts", "Food art"],
        points: [
          "Active Engagement—children participate in tasting sessions, food art, and simple cooking (like making fruit salads or millet laddoos)",
          "Sensory Exploration—smelling, touching, and tasting fresh produce enhances children's sensory skills and food familiarity",
          "Health Awareness—kids learn about the benefits of fruits and millets through interactive stories and group discussions",
          "Creative Activities—children use apples, bananas, and millets in painting, stamping, and collage work, blending food and art",
          "Real-World Connection—parents send a fruit or millet from home, allowing children to share its name, taste, and story with friends",
        ],
        quote:
          "When food becomes fun, children don't just eat well — they learn well.",
      },
      {
        title: "Physical Activity & Development",
        icon: "🤸",
        intro:
          "Movement is essential for every child's growth—physically, emotionally, and socially.",
        tags: ["Active play", "Swimming & cycling", "Motor skills", "Confidence"],
        points: [
          "Daily Activity Time—children enjoy daily active play like running, hopping, skipping, and dancing",
          "Inhouse Adventures—engaging activities such as swimming, cycling, and mud pit play build strength, coordination, and courage",
          "Motor Skill Building—activities are designed to enhance gross motor (whole-body movement) and fine motor (hand-eye coordination) development",
          "Mind-Body Awareness—movement games and stretching activities help children tune into their bodies and improve focus",
          "Confidence Boosting—accomplishing new physical tasks builds resilience and self-esteem",
        ],
        quote:
          "In every jump, splash, and spin — children discover the joy of moving and growing.",
      },
    ],
  },
  {
    id: "tacs",
    code: "T.A.C.S",
    title: "Application & Creative Space",
    icon: "🎨",
    color: "sun",
    summary:
      "Art, imagination, and open-ended making—where ideas find their form.",
    detail:
      "Dedicated creative time lets children express, experiment, and apply learning in joyful, personal ways—through dolls, blocks, clay, and color.",
    examples: [
      {
        title: "Dolls",
        icon: "🧸",
        tags: ["Emotions", "Pretend caregiving", "Storytelling"],
        points: [
          "Emotional Development—playing with dolls helps children express feelings, understand relationships, and build empathy",
          "Role-Play—kids explore real-life situations by pretending to be caregivers, friends, or family members",
          "Language Skills—through dialogues and pretend conversations, children develop storytelling and vocabulary",
        ],
        quote: "In every doll, a child finds a world of emotions waiting to be explored.",
      },
      {
        title: "Building Blocks",
        icon: "🧱",
        tags: ["Towers & structures", "Shapes & balance", "Teamwork", "Coordination"],
        points: [
          "Active Engagement—children build towers, homes, and structures, learning by doing and solving problems",
          "Spatial Awareness—playing with blocks enhances understanding of shape, size, and balance",
          "Collaborative Play—group activities teach sharing, teamwork, and cooperative construction",
          "Fine Motor Development—grasping and stacking blocks sharpens coordination and precision",
        ],
        quote:
          "Every block placed is a step toward building creativity, confidence, and cooperation.",
      },
      {
        title: "Pottery",
        icon: "🏺",
        tags: ["Clay & texture", "Free expression", "Fine motor skills"],
        points: [
          "Sensory Exploration—pottery engages touch and texture, offering a calming and therapeutic experience",
          "Creativity & Expression—children mold clay into animals, shapes, and patterns, expressing their ideas freely",
          "Motor Skill Development—sculpting strengthens fine motor skills and hand-eye coordination",
        ],
        quote: "From a lump of clay emerges the shape of a child's imagination.",
      },
      {
        title: "Art & Painting",
        icon: "🖌️",
        tags: ["Brushes & color", "Self-expression", "Focus & patience"],
        points: [
          "Creative Freedom—kids use brushes, sponges, fingers, and more to create vibrant art pieces",
          "Self-Expression—art becomes an outlet for feelings, ideas, and individuality",
          "Cognitive Growth—learning about colors, shapes, and patterns develops early cognitive skills",
          "Focus & Patience—painting encourages concentration and a sense of accomplishment",
        ],
        quote:
          "With every brushstroke, children paint their thoughts, dreams, and discoveries.",
      },
    ],
  },
];



export type Program = {
  id: string;
  name: string;
  color: "sky" | "leaf" | "coral" | "sun";
  blurb: string;
  points: string[];
};

export const programs: Program[] = [
  {
    id: "preschool",
    name: "Preschool & Kindergarten",
    color: "sky",
    blurb:
      "Foundational early learning for curious minds—language, logic, creativity, and care.",
    points: [
      "Age-appropriate experiential curriculum",
      "Phonics, number sense, and practical life",
      "Social-emotional growth in small groups",
    ],
  },
  {
    id: "daycare",
    name: "Day Care",
    color: "leaf",
    blurb:
      "Nurturing care through the day—routines, rest, meals, and gentle engagement.",
    points: [
      "Safe, supervised environment",
      "Play, rest, and healthy habits",
      "Clear updates for working parents",
    ],
  },
  {
    id: "summer",
    name: "Summer Camps",
    color: "sun",
    blurb:
      "Seasonal adventures packed with crafts, outdoor play, and friendship.",
    points: [
      "Themed creative activities",
      "Movement and outdoor exploration",
      "New friends and lasting memories",
    ],
  },
];

export const developmentAreas = [
  { name: "Physical", note: "Motor skills, coordination, active play" },
  { name: "Math & Logic", note: "Patterns, counting, problem-solving" },
  { name: "Cognitive", note: "Attention, memory, curious thinking" },
  { name: "Creative Expression", note: "Art, music, imagination" },
  { name: "Social", note: "Sharing, empathy, friendship" },
  { name: "General Awareness", note: "World around them, habits, values" },
];

export type Branch = {
  id: string;
  name: string;
  address: string;
  mapQuery: string;
  primary?: boolean;
};

export const branches: Branch[] = [
  {
    id: "munnekolala",
    name: "Munnekolala",
    address:
      "No 25, Opp Ittina Abha Apartments, Munnekolala Main Road, Munnekolala, Bangalore 560037",
    mapQuery:
      "SunKidz Munnekolala Main Road Opp Ittina Abha Apartments Bangalore",
    primary: true,
  },
  {
    id: "ashwath",
    name: "Ashwath Nagar",
    address:
      "No 66, 3rd Cross, Aswathnagar, Marathahalli Post, Bangalore 560037",
    mapQuery: "Ashwath Nagar Marathahalli Bangalore 560037",
  },
  {
    id: "aecs",
    name: "AECS Layout",
    address:
      "694, 2nd Cross Road D Block, AECS Layout - C Block, Bengaluru, Karnataka 560037",
    mapQuery: "AECS Layout C Block Bengaluru 560037",
  },
];

export const about = {
  story:
    "Welcome to SunKidz Kindergarten. We provide a safe and nurturing environment for children to grow and learn—fostering intellectual, social, emotional, and physical development.",
  mission:
    "To inspire a lifelong love of learning by nurturing curiosity, creativity, and confidence in every child. We offer a safe, inclusive, and stimulating space where children explore, discover, and grow into compassionate, capable individuals.",
  vision:
    "To be a leading early childhood centre that empowers young minds to reach their fullest potential—supported academically, emotionally, socially, and physically.",
  wellness:
    "We believe society’s wellness begins with its youngest members. By fostering kindness, empathy, respect, and cooperation early on, we plant seeds for healthier families and communities.",
  uniqueness:
    "Children thrive where their uniqueness is valued. By building on each child’s strengths, interests, and curiosities, we guide them to explore the world and form close relationships.",
  foundations:
    "Our Foundations for Success program focuses on essential skills and lifelong learning—critical thinking, problem-solving, and communication—so every child steps forward with confidence and resilience.",
};

export const navLinks = [
  { to: "/about", label: "About" },
  { to: "/programs", label: "Programs" },
  { to: "/approach", label: "Approach" },
  { to: "/branches", label: "Branches" },
];
