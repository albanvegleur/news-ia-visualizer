const OpenAI = require('openai');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const NEWS_API_KEY = process.env.NEWS_API_KEY;
const GENERATED_FILE = 'generated_articles.json';
const INTERVAL_MINUTES = 15;

function loadGeneratedArticles() {
  if (fs.existsSync(GENERATED_FILE)) {
    return JSON.parse(fs.readFileSync(GENERATED_FILE, 'utf-8'));
  }
  return [];
}

function saveGeneratedArticles(list) {
  fs.writeFileSync(GENERATED_FILE, JSON.stringify(list, null, 2));
}

async function getLatestNews() {
  try {
    const response = await axios.get(`https://newsapi.org/v2/everything?q=France&sortBy=relevancy&apiKey=${NEWS_API_KEY}`);
    console.log("Nombre d'articles trouvés:", response.data.articles.length);
    if (response.data.articles && response.data.articles.length > 0) {
      return response.data.articles;
    } else {
      throw new Error("Aucun article trouvé");
    }
  } catch (error) {
    console.error("Erreur lors de la récupération de l'actualité:", error);
    throw error;
  }
}

async function generateImageForArticle(article) {
  try {
    console.log("\nGénération de l'image pour :", article.title);
    const response = await openai.responses.create({
      model: "gpt-4.1-mini",
      input: `Generate an image based on this news title: ${article.title}`,
      tools: [{ type: "image_generation" }],
    });
    const imageData = response.output
      .filter((output) => output.type === "image_generation_call")
      .map((output) => output.result);
    if (imageData.length > 0) {
      const imageBase64 = imageData[0];
      // Utiliser un nom de fichier basé sur le titre (hashé pour éviter les caractères spéciaux)
      const imageName = `news_image_${Buffer.from(article.title).toString('base64').replace(/[^a-zA-Z0-9]/g, '')}.png`;
      fs.writeFileSync(imageName, Buffer.from(imageBase64, "base64"));
      console.log(`Image ${imageName} générée avec succès !`);
    } else {
      console.error("Aucune image générée");
    }
  } catch (error) {
    console.error("Erreur lors de la génération de l'image:", error);
  }
}

async function generateRandomImage() {
  try {
    const articles = await getLatestNews();
    let generated = loadGeneratedArticles();
    // Filtrer les articles déjà traités (on utilise l'URL comme identifiant unique)
    const notGenerated = articles.filter(a => !generated.includes(a.url));
    if (notGenerated.length === 0) {
      console.log("Tous les articles ont déjà été traités. Réinitialisation de la liste.");
      generated = [];
      saveGeneratedArticles(generated);
      return;
    }
    // Choisir un article aléatoire non traité
    const article = notGenerated[Math.floor(Math.random() * notGenerated.length)];
    await generateImageForArticle(article);
    // Ajouter à la liste des articles traités
    generated.push(article.url);
    saveGeneratedArticles(generated);
  } catch (error) {
    console.error("Erreur lors de la génération d'une image aléatoire:", error);
  }
}

// Lancer une génération immédiate, puis toutes les 15 minutes
(async () => {
  await generateRandomImage();
  setInterval(generateRandomImage, INTERVAL_MINUTES * 60 * 1000);
})(); 