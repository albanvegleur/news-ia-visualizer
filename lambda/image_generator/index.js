const OpenAI = require('openai');
const AWS = require('aws-sdk');
const axios = require('axios');
const s3 = new AWS.S3();

if (!process.env.OPENAI_API_KEY) {
  throw new Error("La variable d'environnement OPENAI_API_KEY est manquante !");
}

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const NEWS_API_KEY = process.env.NEWS_API_KEY;
const BUCKET_NAME = process.env.BUCKET_NAME;
const GENERATED_KEY = 'generated_articles.json';

const ART_STYLES = [
  {
    name: "Fantasy",
    prompt: "epic fantasy concept art, with dramatic lighting, enchanted landscapes, and heroic visual themes — inspired by Lord of the Rings and Elden Ring"
  },
  {
    name: "South Park",
    prompt: "flat 2D cartoon in the style of South Park, with simple shapes, cutout animation style, and exaggerated expressions"
  },
  {
    name: "Cyberpunk",
    prompt: "cyberpunk aesthetic with neon lights, dark futuristic cityscapes, glowing signs, and characters with cybernetic enhancements — inspired by Blade Runner"
  },
  {
    name: "Ghibli",
    prompt: "soft pastel painterly art style inspired by Studio Ghibli, with magical realism, whimsical nature, and emotional warmth"
  }
];

function getRandomArtStyle() {
  return ART_STYLES[Math.floor(Math.random() * ART_STYLES.length)];
}

async function loadGeneratedArticles() {
  try {
    const data = await s3.getObject({ Bucket: BUCKET_NAME, Key: GENERATED_KEY }).promise();
    return JSON.parse(data.Body.toString('utf-8'));
  } catch (err) {
    // Si le fichier n'existe pas, retourner une liste vide
    if (err.code === 'NoSuchKey') return [];
    throw err;
  }
}

async function saveGeneratedArticles(list) {
  await s3.putObject({
    Bucket: BUCKET_NAME,
    Key: GENERATED_KEY,
    Body: JSON.stringify(list, null, 2),
    ContentType: 'application/json',
  }).promise();
}

async function getLatestNews() {
  const response = await axios.get(`https://newsapi.org/v2/everything?q=France&sortBy=relevancy&pageSize=10&apiKey=${NEWS_API_KEY}`);
  if (response.data.articles && response.data.articles.length > 0) {
    return response.data.articles;
  } else {
    throw new Error("Aucun article trouvé");
  }
}

async function generateImageForArticle(article) {
  const style = getRandomArtStyle();
  console.log('Style sélectionné:', style.name);
  console.log('Titre de l\'article:', article.title);

  // Construction du prompt en plusieurs étapes
  const basePrompt = `Create a detailed and artistic illustration for this news headline: "${article.title}"`;
  const stylePrompt = `The image should be in the style of ${style.prompt}`;
  const qualityPrompt = `Focus on creating a visually striking and emotionally resonant scene that captures the essence of the news story. Use rich colors, dynamic composition, and clear visual storytelling.`;

  // Assemblage du prompt final
  const finalPrompt = `${basePrompt}. ${stylePrompt}. ${qualityPrompt}`;

  console.log('Prompt complet:', finalPrompt);

  try {
    // Utilisation de l'API DALL-E 3 pour générer une image
    const response = await openai.images.generate({
      model: "dall-e-3",
      prompt: finalPrompt,
      n: 1,
      size: "1024x1024",
      quality: "standard",
      style: "vivid"
    });

    if (!response.data || response.data.length === 0) {
      throw new Error("Aucune image n'a été générée");
    }

    // Télécharger l'image depuis l'URL
    const imageUrl = response.data[0].url;
    const imageResponse = await axios.get(imageUrl, { responseType: 'arraybuffer' });
    const imageBuffer = Buffer.from(imageResponse.data);
    
    const timestamp = new Date().toISOString();
    const safeTitle = Buffer.from(article.title).toString('base64').replace(/[^a-zA-Z0-9]/g, '');
    const key = `images/${timestamp}_${safeTitle}.png`;
    
    await s3.putObject({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: imageBuffer,
      ContentType: 'image/png',
    }).promise();
    
    console.log('Image uploaded to S3 with key:', key);
    return {
      key,
      style: style.name
    };
  } catch (error) {
    console.error('Erreur détaillée:', error);
    if (error.response) {
      console.error('Réponse de l\'API:', error.response.data);
    }
    if (error.error) {
      console.error('Détails de l\'erreur:', error.error);
    }
    throw error;
  }
}

exports.handler = async (event) => {
  try {
    // 1. Charger les articles déjà traités
    let generated = await loadGeneratedArticles();
    // 2. Récupérer les news
    const articles = await getLatestNews();
    // 3. Filtrer les articles non traités
    const notGenerated = articles.filter(a => !generated.includes(a.url));
    if (notGenerated.length === 0) {
      // Réinitialiser la liste si tout a été traité
      generated = [];
      await saveGeneratedArticles(generated);
      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Tous les articles ont déjà été traités. Réinitialisation.' })
      };
    }
    // 4. Choisir un article aléatoire non traité
    const article = notGenerated[Math.floor(Math.random() * notGenerated.length)];
    // 5. Générer l'image
    const imageResult = await generateImageForArticle(article);
    // 6. Ajouter à la liste des articles traités
    generated.push(article.url);
    await saveGeneratedArticles(generated);
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Image générée et sauvegardée avec succès',
        imageKey: imageResult.key,
        style: imageResult.style,
        articleTitle: article.title,
        articleUrl: article.url
      })
    };
  } catch (error) {
    console.error('Erreur:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Erreur lors de la génération de l\'image',
        error: error.message
      })
    };
  }
}; 