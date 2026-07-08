-- =====================================================
-- READY PLAY! 게시판 Supabase 설정 SQL
-- Supabase 대시보드 → SQL Editor 에 전체 붙여넣기 후 Run
-- =====================================================


-- ① posts 테이블 (게시글)
CREATE TABLE IF NOT EXISTS public.posts (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    author_name     TEXT NOT NULL DEFAULT '익명',
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    category        TEXT NOT NULL DEFAULT '자유',
    is_secret       BOOLEAN DEFAULT FALSE,
    secret_password TEXT,
    view_count      INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ② post_comments 테이블 (댓글)
CREATE TABLE IF NOT EXISTS public.post_comments (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id        UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    author_name    TEXT NOT NULL DEFAULT '익명',
    content        TEXT NOT NULL,
    is_admin_reply BOOLEAN DEFAULT FALSE,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ③ post_attachments 테이블 (첨부파일)
CREATE TABLE IF NOT EXISTS public.post_attachments (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    file_name  TEXT NOT NULL,
    file_url   TEXT NOT NULL,
    file_size  INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- =====================================================
-- 권한 설정 (RLS 비활성화 + 전체 허용)
-- =====================================================
ALTER TABLE public.posts            DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments    DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_attachments DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.posts            TO anon, authenticated;
GRANT ALL ON public.post_comments    TO anon, authenticated;
GRANT ALL ON public.post_attachments TO anon, authenticated;


-- =====================================================
-- Storage 버킷 생성 (첨부파일 업로드용)
-- 아래 SQL은 실행 후 Storage 탭에서 버킷이 생겼는지 확인하세요
-- =====================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('post-files', 'post-files', true)
ON CONFLICT (id) DO NOTHING;

-- Storage 버킷 권한
CREATE POLICY "post-files public read" ON storage.objects
    FOR SELECT USING (bucket_id = 'post-files');

CREATE POLICY "post-files auth upload" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'post-files' AND auth.role() = 'authenticated');

CREATE POLICY "post-files auth delete" ON storage.objects
    FOR DELETE USING (bucket_id = 'post-files' AND auth.uid() = owner);
