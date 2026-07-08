# READY PLAY!

스포츠 용품/유니폼 쇼핑몰 웹사이트입니다. 종목별 상품 카탈로그, 장바구니, 주문, 회원 관리, 리뷰/커뮤니티 게시판, 관리자 페이지로 구성되어 있습니다.

## 주요 기능

- **종목별 카탈로그**: 야구, 농구, 축구, 배구, 러닝, 헬스 (`baseball.html`, `basketball.html`, `soccer.html`, `volleyball.html`, `running.html`, `Health.html`)
- **상품/키트 상세**: `product-detail.html`, `kit-detail.html`
- **쇼핑**: 장바구니(`cart.html`, `mini-cart.html`), 주문서(`orderform.html`), 위시리스트(`wishlist.html`)
- **회원**: 로그인/회원가입(`login.html`, `signup.html`), 비밀번호 재설정(`reset-password.html`), 마이페이지(`mypage.html`)
- **커뮤니티**: 게시글 작성/상세(`write-post.html`, `post-detail.html`), 리뷰(`review.html`), 공지사항(`notice.html`)
- **관리자**: 대시보드, 주문/상품/회원/문의 관리(`admin.html`)

## 기술 스택

- 순수 HTML / CSS / JavaScript (별도 빌드 도구 없음)
- [Supabase](https://supabase.com) — 인증, 데이터베이스(게시판 등) 백엔드 (`common.js`, `supabase-board-setup.sql`)

## 폴더 구조

```
.
├── common.css / common.js   # 공통 스타일 및 스크립트 (Supabase 클라이언트 등)
├── header.html / footer.html
├── img/                     # 이미지 리소스
├── main-banner.mp4          # 메인 배너 영상
├── supabase-board-setup.sql # 게시판 관련 Supabase 테이블/정책 설정
└── *.html                   # 페이지별 화면
```

## 실행 방법

빌드 과정이 필요 없는 정적 사이트입니다. 로컬에서 정적 서버로 실행하세요.

```bash
python3 -m http.server 8000
# 이후 http://localhost:8000 접속
```
