function getCookie(name){
    const arr = document.cookie.match(new RegExp("(^| )"+name+"=([^;]*)(;|$)"));
    if(arr != null) return decodeURIComponent(arr[2]);
    return null;
}
document.getElementById("curUser").innerText = getCookie("token") || "";

const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightboxImg');
const closeBtn = document.getElementById('closeBtn');
const fileInput = document.getElementById('fileInput');
const uploadBtn = document.getElementById('uploadBtn');
const indexView = document.getElementById('indexView');
const timelineView = document.getElementById('timelineView');

closeBtn.addEventListener('click', () => lightbox.style.display='none');
lightbox.addEventListener('click', e => { if(e.target===lightbox) lightbox.style.display='none'; });

function showFull(name){
    lightboxImg.src = 'photos/images/' + encodeURIComponent(name);
    lightbox.style.display = 'flex';
}

// ===== 索引图库 =====
async function loadIndex(){
    const res = await fetch('/api/list');
    const files = await res.json();
    indexView.innerHTML = "";
    files.forEach(name => {
        const card = document.createElement('div');
        card.className = "gallery-item";
        const img = document.createElement('img');
        const thumb = 'photos/images/thumb/' + encodeURIComponent(name);
        const full  = 'photos/images/' + encodeURIComponent(name);
        img.src = thumb; img.loading = "lazy";
        img.onerror = () => img.src = full;
        card.appendChild(img);
        card.onclick = () => showFull(name);
        indexView.appendChild(card);
    });
    if(files.length === 0)
        indexView.innerHTML = '<p style="color:#aaa;text-align:center;width:100%">暂无图片，点右上角「上传图片」</p>';
}

// ===== 时间线图库 =====
let railHideTimer = null;
function buildRail(years){
    let rail = document.getElementById('timelineRail');
    rail.innerHTML = '';
    years.forEach(ym=>{
        const a = document.createElement('a');
        a.innerText = ym;
        a.href = "javascript:void(0)";
        a.onclick = () => {
            const sec = document.getElementById('tl-'+ym);
            if(sec) sec.scrollIntoView({behavior:'smooth'});
        };
        rail.appendChild(a);
    });
}
function armRailHover(){
    document.onmousemove = e => {
        if(timelineView.style.display === 'none') return;
        const rail = document.getElementById('timelineRail');
        if(e.clientX > window.innerWidth - 24){
            rail.style.opacity = 1;
            clearTimeout(railHideTimer);
        } else if(e.clientX < window.innerWidth - 80){
            clearTimeout(railHideTimer);
            railHideTimer = setTimeout(()=>{ rail.style.opacity = 0; }, 3000);
        }
    };
}
async function loadTimeline(){
    const res = await fetch('/api/timeline');
    const groups = await res.json();
    timelineView.innerHTML = "";
    const years = Object.keys(groups).sort().reverse();
    years.forEach(ym=>{
        const sec = document.createElement('section');
        sec.id = 'tl-' + ym;
        const h = document.createElement('h2');
        h.style.cssText = 'padding:24px 16px 0;color:#fff';
        h.innerText = ym;
        sec.appendChild(h);
        const grid = document.createElement('div');
        grid.className = 'gallery-container';
        groups[ym].forEach(name=>{
            const card = document.createElement('div');
            card.className = "gallery-item";
            const img = document.createElement('img');
            const thumb = 'photos/images/thumb/' + encodeURIComponent(name);
            const full  = 'photos/images/' + encodeURIComponent(name);
            img.src = thumb; img.loading = "lazy";
            img.onerror = () => img.src = full;
            card.appendChild(img);
            card.onclick = () => showFull(name);
            grid.appendChild(card);
        });
        sec.appendChild(grid);
        timelineView.appendChild(sec);
    });
    buildRail(years);
    armRailHover();
}

// ===== 菜单切换 =====
const tabIndex = document.getElementById('tabIndex');
const tabTimeline = document.getElementById('tabTimeline');
function switchTab(which){
    const rail = document.getElementById('timelineRail');
    if(which === 'index'){
        indexView.style.display = ''; timelineView.style.display = 'none';
        rail.style.opacity = 0;
        tabIndex.classList.add('active'); tabTimeline.classList.remove('active');
    }else{
        indexView.style.display = 'none'; timelineView.style.display = '';
        tabIndex.classList.remove('active'); tabTimeline.classList.add('active');
        loadTimeline();
    }
}
tabIndex.onclick = () => switchTab('index');
tabTimeline.onclick = () => switchTab('timeline');

// ===== 上传 =====
uploadBtn.onclick = () => fileInput.click();
fileInput.addEventListener('change', async () => {
    const files = Array.from(fileInput.files);
    if(files.length === 0) return;
    uploadBtn.disabled = true; uploadBtn.innerText = '上传中...';
    for(const file of files){
        try{
            const res = await fetch('/api/upload?name='+encodeURIComponent(file.name), {method:'POST', body:file});
            const ret = await res.json();
            if(!ret.ok) alert('上传失败: ' + (ret.msg||''));
        }catch(e){ alert('上传异常: '+e.message); }
    }
    uploadBtn.disabled = false; uploadBtn.innerText = '上传图片';
    fileInput.value = '';
    loadIndex();
});

window.onload = loadIndex;
