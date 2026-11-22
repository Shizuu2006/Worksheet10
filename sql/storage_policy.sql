-- Buat bucket "kosfinder-demo" terlebih dahulu di Supabase Storage.
-- Bucket public hanya untuk foto demo nonprivat.
-- Tambahkan batas ukuran 5 MB dan MIME image/jpeg serta image/png.

-- Hapus policy lama dengan nama yang sama jika pernah dibuat.
DROP POLICY IF EXISTS "ws10_demo_upload_own_folder" ON storage.objects;

CREATE POLICY "ws10_demo_upload_own_folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'kosfinder-demo'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);
