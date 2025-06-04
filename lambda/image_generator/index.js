const OpenAI = require('openai');
const AWS = require('aws-sdk');
const axios = require('axios');
const s3 = new AWS.S3();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const NEWS_API_KEY = process.env.NEWS_API_KEY;
const BUCKET_NAME = process.env.BUCKET_NAME;
const GENERATED_KEY = 'generated_articles.json';

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
  // Utilisation de la nouvelle API OpenAI pour générer une image à partir du titre de l'article
  const response = await openai.images.generate({
    model: "dall-e-3",
    prompt: `Génère une image pour cet article : ${article.title}`,
    n: 1,
    size: "1024x1024"
  });
  
  const imageUrl = response.data[0].url;
  // Télécharger l'image depuis l'URL
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
  return key;
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
    const imageKey = await generateImageForArticle(article);
    // 6. Ajouter à la liste des articles traités
    generated.push(article.url);
    await saveGeneratedArticles(generated);
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Image générée et sauvegardée avec succès',
        imageKey,
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