// =================================================================
// common.js — Ready Play! 공통 스크립트
// 모든 페이지에서 공유하는 함수 모음
// 기준: login.html / signup.html (readyplayUser 방식)
// =================================================================


// --- [1] Supabase 설정 ---
// 모든 페이지에서 같은 URL과 KEY를 사용 (login.html 기준)
const RP_SUPABASE_URL = 'https://qdcysdousmdfucuvdcgt.supabase.co';
const RP_SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkY3lzZG91c21kZnVjdXZkY2d0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4Njg3OTksImV4cCI6MjA4OTQ0NDc5OX0.rHdhb-VsNR7hs08-sY0lLybFDDNu1rvZw2GS6wpeu3I';

// Supabase 클라이언트 싱글톤 (한 번만 초기화해서 재사용)
// 사용법: const sb = getSupabase();
function getSupabase() {
    if (!window._supabase) {
        if (typeof supabase === 'undefined') {
            console.error('[ReadyPlay] Supabase CDN 스크립트가 로드되지 않았습니다.');
            return null;
        }
        window._supabase = supabase.createClient(RP_SUPABASE_URL, RP_SUPABASE_KEY);
    }
    return window._supabase;
}


// --- [2] 헤더/푸터 로드 ---
// 모든 페이지의 DOMContentLoaded에서 이 함수를 호출하면 됨
// 사용법: document.addEventListener('DOMContentLoaded', loadLayout);
async function loadLayout() {
    try {
        // 헤더와 푸터를 동시에 요청 (더 빠름)
        const [headerRes, footerRes] = await Promise.all([
            fetch('header.html'),
            fetch('footer.html')
        ]);

        const headerContainer = document.getElementById('header-container');
        const footerContainer = document.getElementById('footer-container');

        if (headerContainer) {
            headerContainer.innerHTML = await headerRes.text();
            // header.html 안에 있는 <script> 태그를 다시 실행
            headerContainer.querySelectorAll('script').forEach(old => {
                const s = document.createElement('script');
                s.text = old.text;
                document.body.appendChild(s).parentNode.removeChild(s);
            });
        }

        if (footerContainer) {
            footerContainer.innerHTML = await footerRes.text();
            // footer.html 안에 있는 <script> 태그를 다시 실행
            footerContainer.querySelectorAll('script').forEach(old => {
                const s = document.createElement('script');
                s.text = old.text;
                document.body.appendChild(s).parentNode.removeChild(s);
            });
        }

        // 레이아웃 로드 완료 후 로그인 상태 반영
        updateLoginStatus();

    } catch (e) {
        console.error('[ReadyPlay] 레이아웃 로드 실패:', e);
    }
}


// --- [3] 로그인 상태 업데이트 ---
// login.html 기준: sessionStorage의 'readyplayUser' JSON 객체를 읽어옴
// { isLoggedIn: true, userName: "홍길동", userRole: "member" }
function updateLoginStatus() {
    const topAuthBtn  = document.getElementById('top-auth-btn');
    const sideAuthBtn = document.getElementById('side-auth-btn');
    const sessionData = sessionStorage.getItem('readyplayUser');

    if (sessionData) {
        try {
            const userData = JSON.parse(sessionData);
            if (userData.isLoggedIn === true) {
                // 로그인 상태 → 버튼을 LOGOUT으로 변경
                if (topAuthBtn) {
                    topAuthBtn.innerText = 'LOGOUT';
                    topAuthBtn.onclick   = handleLogout;
                }
                if (sideAuthBtn) {
                    sideAuthBtn.innerText = `LOGOUT (${userData.userName}님)`;
                    sideAuthBtn.onclick   = handleLogout;
                }
                return;
            }
        } catch (e) {
            console.error('[ReadyPlay] 세션 데이터 파싱 오류:', e);
        }
    }

    // 비로그인 상태 → 버튼을 LOGIN으로 유지
    if (topAuthBtn) {
        topAuthBtn.innerText = 'LOGIN';
        topAuthBtn.onclick   = () => location.href = 'login.html';
    }
    if (sideAuthBtn) {
        sideAuthBtn.innerText = 'LOGIN';
        sideAuthBtn.onclick   = () => location.href = 'login.html';
    }
}


// --- [4] 로그아웃 ---
async function handleLogout() {
    if (confirm('로그아웃 하시겠습니까?')) {
        // Supabase 세션도 함께 종료
        try {
            const sb = getSupabase();
            if (sb) await sb.auth.signOut();
        } catch (e) { /* Supabase 없는 페이지에서는 그냥 넘어감 */ }

        sessionStorage.removeItem('readyplayUser');
        alert('로그아웃 되었습니다.');
        location.href = 'index.html';
    }
}


// --- [5] 현재 로그인한 사용자 정보 가져오기 ---
// 사용법: const user = getCurrentUser();  → null이면 비로그인
function getCurrentUser() {
    const sessionData = sessionStorage.getItem('readyplayUser');
    if (sessionData) {
        try { return JSON.parse(sessionData); } catch (e) {}
    }
    return null;
}


// --- [6] 마이페이지 이동 (로그인 필수 체크) ---
function checkLoginAndMove() {
    const user = getCurrentUser();
    if (user && user.isLoggedIn === true) {
        location.href = 'mypage.html';
    } else {
        alert('로그인이 필요한 서비스입니다.');
        location.href = 'login.html';
    }
}


// --- [7] 관리자 페이지 이동 (관리자 권한 체크) ---
// 나중에 admin.html 만들 때 헤더 버튼에 연결하면 됨
// userRole === 'admin' 인 계정만 접근 허용
function checkAdminAndMove() {
    const user = getCurrentUser();
    if (user && user.isLoggedIn === true) {
        if (user.userRole === 'admin') {
            location.href = 'admin.html';
        } else {
            alert('관리자 권한이 필요합니다.');
        }
    } else {
        alert('로그인이 필요한 서비스입니다.');
        location.href = 'login.html';
    }
}


// --- [8] 사이드바 메뉴 토글 ---
// header.html의 ☰ 버튼 onclick="toggleMenu()" 에 연결됨
function toggleMenu() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('overlay');
    if (sidebar && overlay) {
        sidebar.classList.toggle('active');
        overlay.classList.toggle('active');
    }
}


// --- [9] 사이드바 서브메뉴 토글 ---
// header.html의 STORE, COMMUNITY 메뉴 onclick="toggleSubmenu('id')" 에 연결됨
function toggleSubmenu(id) {
    const sub = document.getElementById(id);
    if (!sub) return;
    sub.classList.toggle('open');
    const icon = sub.previousElementSibling.querySelector('span');
    if (icon) icon.innerText = sub.classList.contains('open') ? '-' : '+';
}


// --- [10] 찜하기 (위시리스트 추가) ---
// store.html 방식 기준으로 통일
// 사용법: addToWishlist('축구 스타터 키트', '110,000원', 'SOCCER', 'soccer_store.png')
function addToWishlist(name, price, category, imgSrc) {
    let wishlist = JSON.parse(sessionStorage.getItem('Wishlist')) || [];

    const newItem = {
        id:      Date.now(),
        name:    name,
        options: '기본 구성 (' + category + ')',
        price:   price,
        img:     imgSrc,
        date:    new Date().toLocaleDateString()
    };

    // 이미 담긴 상품인지 확인
    const isExist = wishlist.some(item => item.name === name);
    if (isExist) {
        if (!confirm('이미 찜 목록에 있는 상품입니다. 하나 더 추가하시겠습니까?')) return;
    }

    wishlist.push(newItem);
    sessionStorage.setItem('Wishlist', JSON.stringify(wishlist));

    if (confirm('♥ 찜 목록에 담겼습니다!\n찜 목록 페이지로 이동하시겠습니까?')) {
        location.href = 'wishlist.html';
    }
}
