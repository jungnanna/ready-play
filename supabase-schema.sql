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
-- 권한 설정 (RLS)
-- anon key는 브라우저에 그대로 노출되는 공개 키라서, 실제 접근
-- 제어는 이 RLS 정책이 담당한다. 관리자 여부는 profiles.role을
-- 보고 판단하는데, profiles 테이블 자신의 정책 안에서 profiles를
-- 다시 조회하면 재귀 문제가 생기므로 SECURITY DEFINER 함수
-- (is_admin)로 우회해서 확인한다.
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    );
$$;

-- 게시글 조회수 증가 전용 함수.
-- posts UPDATE 권한을 글쓴이/관리자로 제한하면 조회수 증가(비회원 포함,
-- 모든 방문자가 트리거)도 막히므로, view_count 한 컬럼만 올려주는
-- 이 함수만 별도로 anon/authenticated에게 실행 권한을 준다.
CREATE OR REPLACE FUNCTION public.increment_view_count(post_id UUID)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.posts SET view_count = COALESCE(view_count, 0) + 1 WHERE id = post_id;
$$;
GRANT EXECUTE ON FUNCTION public.increment_view_count(UUID) TO anon, authenticated;


ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_logs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_attachments  ENABLE ROW LEVEL SECURITY;

-- ── profiles: 본인 행만 CRUD, 관리자는 전체 조회/수정/삭제 ──
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;

DROP POLICY IF EXISTS "profiles select own or admin" ON public.profiles;
CREATE POLICY "profiles select own or admin" ON public.profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "profiles insert own" ON public.profiles;
CREATE POLICY "profiles insert own" ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles update own or admin" ON public.profiles;
CREATE POLICY "profiles update own or admin" ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "profiles delete admin only" ON public.profiles;
CREATE POLICY "profiles delete admin only" ON public.profiles
    FOR DELETE TO authenticated
    USING (public.is_admin());

-- ── products: 목록/상세는 누구나, 등록/삭제는 관리자만 ──
GRANT SELECT ON public.products TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.products TO authenticated;

DROP POLICY IF EXISTS "products select all" ON public.products;
CREATE POLICY "products select all" ON public.products
    FOR SELECT TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "products write admin only" ON public.products;
CREATE POLICY "products write admin only" ON public.products
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ── orders: 본인 주문만(비회원 주문은 user_id가 NULL), 관리자는 전체 ──
GRANT SELECT, INSERT, UPDATE ON public.orders TO anon, authenticated;

DROP POLICY IF EXISTS "orders select own or admin" ON public.orders;
CREATE POLICY "orders select own or admin" ON public.orders
    FOR SELECT TO anon, authenticated
    USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "orders insert own or guest" ON public.orders;
CREATE POLICY "orders insert own or guest" ON public.orders
    FOR INSERT TO anon, authenticated
    WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

DROP POLICY IF EXISTS "orders update own or admin" ON public.orders;
CREATE POLICY "orders update own or admin" ON public.orders
    FOR UPDATE TO anon, authenticated
    USING (user_id = auth.uid() OR public.is_admin());

-- ── contact_logs: 문의는 누구나 등록, 조회는 관리자만 ──
GRANT INSERT ON public.contact_logs TO anon, authenticated;
GRANT SELECT ON public.contact_logs TO authenticated;

DROP POLICY IF EXISTS "contact_logs insert all" ON public.contact_logs;
CREATE POLICY "contact_logs insert all" ON public.contact_logs
    FOR INSERT TO anon, authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "contact_logs select admin only" ON public.contact_logs;
CREATE POLICY "contact_logs select admin only" ON public.contact_logs
    FOR SELECT TO authenticated
    USING (public.is_admin());

-- ── posts: 조회는 누구나(비밀글 잠금은 프론트에서 처리하는 기존 방식 유지),
--    작성은 로그인 회원 본인 글만, 삭제는 글쓴이/관리자. 조회수는 위의
--    increment_view_count() 함수로만 올리므로 UPDATE 권한은 주지 않는다.
GRANT SELECT, INSERT, DELETE ON public.posts TO anon, authenticated;

DROP POLICY IF EXISTS "posts select all" ON public.posts;
CREATE POLICY "posts select all" ON public.posts
    FOR SELECT TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "posts insert own" ON public.posts;
CREATE POLICY "posts insert own" ON public.posts
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "posts delete own or admin" ON public.posts;
CREATE POLICY "posts delete own or admin" ON public.posts
    FOR DELETE TO anon, authenticated
    USING (user_id = auth.uid() OR public.is_admin());

-- ── post_comments: 조회는 누구나, 작성은 로그인 회원 본인, 삭제는 작성자/관리자 ──
GRANT SELECT, INSERT, DELETE ON public.post_comments TO anon, authenticated;

DROP POLICY IF EXISTS "post_comments select all" ON public.post_comments;
CREATE POLICY "post_comments select all" ON public.post_comments
    FOR SELECT TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "post_comments insert own" ON public.post_comments;
CREATE POLICY "post_comments insert own" ON public.post_comments
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "post_comments delete own or admin" ON public.post_comments;
CREATE POLICY "post_comments delete own or admin" ON public.post_comments
    FOR DELETE TO anon, authenticated
    USING (user_id = auth.uid() OR public.is_admin());

-- ── post_attachments: 조회는 누구나, 첨부는 해당 글의 작성자만 ──
GRANT SELECT, INSERT ON public.post_attachments TO anon, authenticated;

DROP POLICY IF EXISTS "post_attachments select all" ON public.post_attachments;
CREATE POLICY "post_attachments select all" ON public.post_attachments
    FOR SELECT TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "post_attachments insert own post" ON public.post_attachments;
CREATE POLICY "post_attachments insert own post" ON public.post_attachments
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.posts
            WHERE posts.id = post_attachments.post_id AND posts.user_id = auth.uid()
        )
    );


-- =====================================================
-- Storage 버킷 생성 (게시글 첨부파일 업로드용)
-- 실행 후 Storage 탭에서 'post-files' 버킷이 생겼는지 확인
-- =====================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('post-files', 'post-files', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "post-files public read" ON storage.objects;
CREATE POLICY "post-files public read" ON storage.objects
    FOR SELECT USING (bucket_id = 'post-files');

DROP POLICY IF EXISTS "post-files auth upload" ON storage.objects;
CREATE POLICY "post-files auth upload" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'post-files' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "post-files auth delete" ON storage.objects;
CREATE POLICY "post-files auth delete" ON storage.objects
    FOR DELETE USING (bucket_id = 'post-files' AND auth.uid() = owner);


-- =====================================================
-- 첫 관리자 계정 만들기
-- 1) 사이트에서 일반 회원가입을 먼저 진행하세요 (signup.html)
-- 2) 그 다음 아래 UPDATE의 이메일을 본인 것으로 바꿔서 실행하면
--    해당 계정이 관리자가 됩니다.
-- =====================================================
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'YOUR_EMAIL@example.com';
