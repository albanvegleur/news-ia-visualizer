const { S3Client, ListObjectsV2Command, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const s3Client = new S3Client({ region: 'eu-west-3' });

exports.handler = async (event) => {
    console.log('Début de l\'exécution de la fonction');
    
    try {
        console.log('Listing des objets dans le bucket');
        const bucketName = 'news-visualizer-images-dev';
        
        // Récupérer la liste des objets dans le bucket
        const listCommand = new ListObjectsV2Command({
            Bucket: bucketName
        });
        
        const listedObjects = await s3Client.send(listCommand);
        console.log('Objets trouvés:', listedObjects.Contents?.length || 0);
        
        if (!listedObjects.Contents || listedObjects.Contents.length === 0) {
            console.log('Aucun objet trouvé dans le bucket');
            return {
                statusCode: 200,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,GET'
                },
                body: JSON.stringify({ images: [] })
            };
        }

        // Générer les URLs signées pour chaque image
        const filteredItems = listedObjects.Contents.filter(item => item.Key.startsWith('images/') && item.Key.endsWith('.png'));
        console.log('Images filtrées:', filteredItems.length);
        const images = await Promise.all(filteredItems.map(async (item) => {
            console.log('Traitement de l\'image:', item.Key);
            const titleBase64 = item.Key.split('_').slice(1).join('_').replace('.png', '');
            const title = Buffer.from(titleBase64, 'base64').toString('utf-8');
            console.log('Titre extrait:', title);
            
            const getObjectCommand = new GetObjectCommand({
                Bucket: bucketName,
                Key: item.Key
            });
            
            const url = await getSignedUrl(s3Client, getObjectCommand, { expiresIn: 3600 });
            console.log('URL signée générée pour:', item.Key);
            
            return {
                key: item.Key,
                url: url,
                lastModified: item.LastModified,
                title: title
            };
        }));
        
        console.log('Nombre d\'images traitées:', images.length);
        
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,GET'
            },
            body: JSON.stringify({ images })
        };
    } catch (error) {
        console.error('Erreur lors de la récupération des images:', error);
        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,GET'
            },
            body: JSON.stringify({ error: error.message })
        };
    }
}; 