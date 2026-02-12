
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import fetch from 'node-fetch';

// Load env vars
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('Testing Supabase Connection...');
console.log('URL:', supabaseUrl);
console.log('Key exists:', !!supabaseKey);

if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase credentials');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
    global: {
        fetch: fetch as any,
    }
});

async function testUpload() {
    try {
        console.log('Listing buckets...');
        const { data: buckets, error: bucketsError } = await supabase.storage.listBuckets();
        
        if (bucketsError) {
            console.error('Error listing buckets:', bucketsError);
            return;
        }
        
        console.log('Buckets:', buckets.map(b => b.name));

        const bucketName = 'events';
        const fileName = `test_signed_url_${Date.now()}.txt`;
        const fileContent = Buffer.from('Hello via Signed URL!');

        console.log(`Generating Signed Upload URL for ${fileName}...`);
        
        const { data, error } = await supabase.storage
            .from(bucketName)
            .createSignedUploadUrl(fileName);

        if (error) {
            console.error('Error creating signed URL:', error);
            return;
        }

        console.log('Signed URL generated:', data.signedUrl);

        console.log('Uploading file via PUT to signed URL...');
        
        const uploadResponse = await fetch(data.signedUrl, {
            method: 'PUT',
            body: fileContent,
            headers: {
                'Content-Type': 'text/plain',
            }
        });

        if (!uploadResponse.ok) {
            console.error('Upload failed:', uploadResponse.status, uploadResponse.statusText);
            const text = await uploadResponse.text();
            console.error('Response:', text);
            return;
        }

        console.log('Upload successful!');

        const { data: publicUrlData } = supabase.storage
            .from(bucketName)
            .getPublicUrl(fileName);
            
        console.log('Public URL:', publicUrlData.publicUrl);

    } catch (err) {
        console.error('Unexpected error:', err);
    }
}

testUpload();
