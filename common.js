// =================================================================
// common.js — Ready Play! 공통 스크립트
// 모든 페이지에서 공유하는 함수 모음 (헤더/푸터 로드, 로그인 상태, 위시리스트 등)
// 세션 상태는 sessionStorage의 'readyplayUser' 키 하나로 통일해서 관리한다.
// =================================================================


// --- [1] Supabase 설정 ---
// URL/KEY를 여기 하드코딩하지 않고 env.js(gitignore 처리됨)에서 주입받는다.
// 리포에 키가 커밋되는 걸 막기 위함 — 새 환경에서는 env.example.js를 복사해 채울 것.
if (!window.RP_ENV) {
    console.error('[ReadyPlay] env.js가 로드되지 않았습니다. env.example.js를 복사해 env.js를 만들어주세요.');
}
const RP_SUPABASE_URL = window.RP_ENV?.SUPABASE_URL;
const RP_SUPABASE_KEY = window.RP_ENV?.SUPABASE_KEY;

/**
 * Supabase 클라이언트를 반환한다. 페이지당 한 번만 생성해서 재사용하는
 * 싱글톤 — createClient()를 호출마다 새로 만들면 불필요한 세션/커넥션이
 * 중복 생성되기 때문에 window._supabase에 캐싱한다.
 * @returns {SupabaseClient|null} CDN 스크립트가 없으면 null
 */
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


/**
 * header.html / footer.html을 fetch로 불러와 각각 #header-container,
 * #footer-container에 주입한다. 모든 페이지가 동일한 헤더/푸터 마크업을
 * 반복해서 들고 있지 않도록 공통 컴포넌트처럼 재사용하기 위함.
 * 페이지의 DOMContentLoaded에서 호출한다: document.addEventListener('DOMContentLoaded', loadLayout);
 */
async function loadLayout() {
    try {
        // 헤더/푸터를 순차 fetch가 아닌 Promise.all로 동시에 요청해 로딩 시간을 절반으로 줄인다.
        const [headerRes, footerRes] = await Promise.all([
            fetch('header.html'),
            fetch('footer.html')
        ]);

        const headerContainer = document.getElementById('header-container');
        const footerContainer = document.getElementById('footer-container');

        if (headerContainer) {
            headerContainer.innerHTML = await headerRes.text();
            // innerHTML로 삽입된 <script>는 브라우저가 자동 실행하지 않으므로,
            // 태그를 새로 만들어 다시 appendChild 해줘야 안의 코드가 동작한다.
            headerContainer.querySelectorAll('script').forEach(old => {
                const s = document.createElement('script');
                s.text = old.text;
                document.body.appendChild(s).parentNode.removeChild(s);
            });
        }

        if (footerContainer) {
            footerContainer.innerHTML = await footerRes.text();
            // 위 header와 동일한 이유로 footer의 <script>도 수동 재실행이 필요하다.
            footerContainer.querySelectorAll('script').forEach(old => {
                const s = document.createElement('script');
                s.text = old.text;
                document.body.appendChild(s).parentNode.removeChild(s);
            });
        }

        // 로그인/로그아웃 버튼은 header.html 안에 있으므로, 헤더가 실제로
        // DOM에 삽입된 이후에 호출해야 요소를 찾을 수 있다.
        updateLoginStatus();

    } catch (e) {
        console.error('[ReadyPlay] 레이아웃 로드 실패:', e);
    }
}


/**
 * 헤더의 로그인/로그아웃 버튼(#top-auth-btn, #side-auth-btn)을 현재 세션에
 * 맞게 갱신한다. sessionStorage의 'readyplayUser'에는
 * { isLoggedIn, userName, userRole } 형태의 JSON이 저장되어 있다고 가정한다.
 */
function updateLoginStatus() {
    const topAuthBtn  = document.getElementById('top-auth-btn');
    const sideAuthBtn = document.getElementById('side-auth-btn');
    const sessionData = sessionStorage.getItem('readyplayUser');

    if (sessionData) {
        try {
            const userData = JSON.parse(sessionData);
            if (userData.isLoggedIn === true) {
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

    if (topAuthBtn) {
        topAuthBtn.innerText = 'LOGIN';
        topAuthBtn.onclick   = () => location.href = 'login.html';
    }
    if (sideAuthBtn) {
        sideAuthBtn.innerText = 'LOGIN';
        sideAuthBtn.onclick   = () => location.href = 'login.html';
    }
}


/**
 * 로그아웃 처리. sessionStorage만 지우면 Supabase 쪽 인증 세션은 남아있게
 * 되므로, auth.signOut()도 함께 호출해 두 상태를 동기화한다.
 */
async function handleLogout() {
    if (confirm('로그아웃 하시겠습니까?')) {
        try {
            const sb = getSupabase();
            if (sb) await sb.auth.signOut();
        } catch (e) { /* Supabase가 초기화되지 않은 페이지도 있으므로 실패해도 무시하고 진행 */ }

        sessionStorage.removeItem('readyplayUser');
        alert('로그아웃 되었습니다.');
        location.href = 'index.html';
    }
}


/**
 * 현재 로그인한 사용자 정보를 반환한다.
 * @returns {{isLoggedIn: boolean, userName: string, userRole: string}|null} 비로그인이면 null
 */
function getCurrentUser() {
    const sessionData = sessionStorage.getItem('readyplayUser');
    if (sessionData) {
        try { return JSON.parse(sessionData); } catch (e) {}
    }
    return null;
}


/**
 * 마이페이지로 이동한다. 로그인 안 된 상태면 로그인 페이지로 대신 보낸다.
 */
function checkLoginAndMove() {
    const user = getCurrentUser();
    if (user && user.isLoggedIn === true) {
        location.href = 'mypage.html';
    } else {
        alert('로그인이 필요한 서비스입니다.');
        location.href = 'login.html';
    }
}


/**
 * 관리자 페이지(admin.html)로 이동한다. userRole이 'admin'인 계정만
 * 통과시킨다 — 실제 접근 제어는 이 프론트엔드 체크뿐이므로, Supabase
 * 쪽에서 role을 직접 바꾸면 우회 가능하다는 점은 감안해야 한다.
 */
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


/**
 * 사이드바 메뉴를 열고 닫는다. header.html의 ☰ 버튼(onclick="toggleMenu()")에서 호출됨.
 */
function toggleMenu() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('overlay');
    if (sidebar && overlay) {
        sidebar.classList.toggle('active');
        overlay.classList.toggle('active');
    }
}


/**
 * 사이드바 내 서브메뉴(STORE, COMMUNITY 등)를 펼치고 접는다.
 * header.html에서 onclick="toggleSubmenu('id')"로 호출됨.
 */
function toggleSubmenu(id) {
    const sub = document.getElementById(id);
    if (!sub) return;
    sub.classList.toggle('open');
    const icon = sub.previousElementSibling.querySelector('span');
    if (icon) icon.innerText = sub.classList.contains('open') ? '-' : '+';
}


/**
 * 상품을 위시리스트(sessionStorage 'Wishlist')에 담는다.
 * @example addToWishlist('축구 스타터 키트', '110,000원', 'SOCCER', 'soccer_store.png')
 */
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
