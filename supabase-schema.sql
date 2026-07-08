-- =====================================================
-- READY PLAY! 전체 Supabase 스키마 (신규 프로젝트용)
-- Supabase 대시보드 → SQL Editor 에 전체 붙여넣기 후 Run
--
-- 주의: 이 파일은 코드(*.html)에서 실제 사용하는 컬럼을
-- 역추적해서 재구성한 것입니다. 원래 프로젝트가 파기되어
-- 실제 컬럼 타입/제약조건과 100% 동일하다는 보장은 없으니,
-- 연결 후 회원가입/로그인/주문/게시판 기능을 하나씩 테스트하며
-- 에러 메시지에 따라 컬럼을 보정해주세요.
-- =====================================================


-- ① profiles 테이블 (회원 정보 — auth.users와 1:1)
-- signup.html에서 auth.signUp() 직후 수동으로 insert 합니다.
CREATE TABLE IF NOT EXISTS public.profiles (
    id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email      TEXT,
    name       TEXT,
    phone      TEXT,
    postcode   TEXT,
    addr       TEXT,
    detail     TEXT,
    role       TEXT DEFAULT 'member',   -- 'member' 또는 'admin'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ② products 테이블 (상품)
CREATE TABLE IF NOT EXISTS public.products (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name        TEXT NOT NULL,
    category    TEXT,
    price       INT NOT NULL,
    img         TEXT,
    description TEXT,
    stock       INT DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ③ orders 테이블 (주문)
CREATE TABLE IF NOT EXISTS public.orders (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,  -- 비회원 주문은 NULL
    user_name    TEXT,
    email        TEXT,
    phone        TEXT,
    postcode     TEXT,
    addr         TEXT,
    detail       TEXT,
    items        JSONB,          -- 주문 상품 목록
    total_price  INT,
    pay_method   TEXT,
    status       TEXT DEFAULT '결제완료',
    order_number TEXT,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ④ contact_logs 테이블 (1:1 문의)
CREATE TABLE IF NOT EXISTS public.contact_logs (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name       TEXT,
    email      TEXT,
    message    TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ⑤ posts 테이블 (게시글)
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

-- ⑥ post_comments 테이블 (댓글)
CREATE TABLE IF NOT EXISTS public.post_comments (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id        UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    author_name    TEXT NOT NULL DEFAULT '익명',
    content        TEXT NOT NULL,
    is_admin_reply BOOLEAN DEFAULT FALSE,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ⑦ post_attachments 테이블 (첨부파일)
CREATE TABLE IF NOT EXISTS public.post_attachments (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    file_name  TEXT NOT NULL,
    file_url   TEXT NOT NULL,
    file_size  INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- =====================================================
-- 권한 설정
-- [보안 주의] 기존 프로젝트와 동일하게 RLS를 비활성화하고
-- anon/authenticated에게 전체 권한을 부여합니다. 이는 관리자
-- 권한 체크를 전적으로 프론트엔드(admin.html)에서만 하고 있다는
-- 뜻이라 실제 서비스 운영 시에는 취약합니다 (누구나 API로
-- products/orders/profiles를 직접 조작 가능). 가능하면 이후
-- RLS 정책으로 교체하는 것을 권장합니다.
-- =====================================================
ALTER TABLE public.profiles          DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products          DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders            DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_logs      DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts             DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments     DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_attachments  DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.profiles          TO anon, authenticated;
GRANT ALL ON public.products          TO anon, authenticated;
GRANT ALL ON public.orders            TO anon, authenticated;
GRANT ALL ON public.contact_logs      TO anon, authenticated;
GRANT ALL ON public.posts             TO anon, authenticated;
GRANT ALL ON public.post_comments     TO anon, authenticated;
GRANT ALL ON public.post_attachments  TO anon, authenticated;


-- =====================================================
-- Storage 버킷 생성 (게시글 첨부파일 업로드용)
-- 실행 후 Storage 탭에서 'post-files' 버킷이 생겼는지 확인
-- =====================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('post-files', 'post-files', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "post-files public read" ON storage.objects
    FOR SELECT USING (bucket_id = 'post-files');

CREATE POLICY "post-files auth upload" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'post-files' AND auth.role() = 'authenticated');

CREATE POLICY "post-files auth delete" ON storage.objects
    FOR DELETE USING (bucket_id = 'post-files' AND auth.uid() = owner);


-- =====================================================
-- 첫 관리자 계정 만들기
-- 1) 사이트에서 일반 회원가입을 먼저 진행하세요 (signup.html)
-- 2) 그 다음 아래 UPDATE의 이메일을 본인 것으로 바꿔서 실행하면
--    해당 계정이 관리자가 됩니다.
-- =====================================================
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'YOUR_EMAIL@example.com';
