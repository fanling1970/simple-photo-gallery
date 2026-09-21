function getCookie(name){
    const arr = document.cookie.match(new RegExp("(^| )"+name+"=([^;]*)(;|$)"));
    if(arr != null) return decodeURIComponent(arr[2]);
    return null;
}
document.getElementById("curUser").innerText = getCookie("token") || "";

const lightbox = document.getElementById('lightbox');
const lbContent = document.getElementById('lbContent');
const closeBtn = document.getElementById('closeBtn');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');
const fileInput = document.getElementById('fileInput');
const uploadBtn = document.getElementById('uploadBtn');
const indexView = document.getElementById('indexView');
const timelineView = document.getElementById('timelineView');

const isVideoName = n => /\.(mp4|webm|mov|mkv|avi)$/i.test(n);
function mediaUrl(p){ return 'photos/images/' + p; }
function thumbUrl(p){ const i=p.lastIndexOf('/'); return p.slice(0,i+1)+'thumb/'+p.slice(i+1); }

let viewerList = [], viewerIndex = 0;
let scale = 1, offX = 0, offY = 0;
let dragging = false, moved = false, startX = 0, startY = 0;

function applyTransform(){
    const el = lbContent.firstChild;
    if(el) el.style.transform = `translate(${offX}px,${offY}px) scale(${scale})`;
}

function makeViewerEl(name){
    let el;
    if(isVideoName(name)){
        el = document.createElement('video');
        el.src = mediaUrl(name); el.controls = true; el.autoplay = true;
    }else{
        el = document.createElement('img');
        el.src = mediaUrl(name);
    }
    el.className = 'lightbox-img';
    el.draggable = false;
    el.addEventListener('dragstart', e => e.preventDefault());
    return el;
}

function renderViewer(){
    lbContent.innerHTML = '';
    const el = makeViewerEl(viewerList[viewerIndex]);
    lbContent.appendChild(el);
    scale = 1; offX = 0; offY = 0;
    applyTransform();
}

function openViewer(name){
    const i = viewerList.indexOf(name);
    if(i >= 0) viewerIndex = i;
    renderViewer();
    lightbox.style.display = 'flex';
}

function closeViewer(){
    lightbox.style.display = 'none';
    lbContent.innerHTML = '';
}

function go(dir){
    const old = lbContent.firstChild;
    viewerIndex = (viewerIndex + dir + viewerList.length) % viewerList.length;
    const el = makeViewerEl(viewerList[viewerIndex]);
    el.style.transition = 'none';
    el.style.transform = `translateX(${dir > 0 ? window.innerWidth : -window.innerWidth}px)`;
    lbContent.appendChild(el);
    void el.offsetWidth;
    el.style.transition = 'transform .3s ease';
    el.style.transform = 'translateX(0) scale(1)';
    if(old){
        old.style.transition = 'transform .3s ease';
        old.style.transform = `translateX(${dir > 0 ? -window.innerWidth : window.innerWidth}px)`;
    }
    setTimeout(()=>{ if(old) old.remove(); scale=1; offX=0; offY=0; }, 320);
}

closeBtn.onclick = closeViewer;
lightbox.addEventListener('click', e => { if(e.target === lightbox) closeViewer(); });
prevBtn.onclick = e => { e.stopPropagation(); go(-1); };
nextBtn.onclick = e => { e.stopPropagation(); go(1); };

lightbox.addEventListener('wheel', e => {
    e.preventDefault();
    scale = Math.min(5, Math.max(1, scale * (e.deltaY < 0 ? 1.15 : 0.87)));
    applyTransform();
}, {passive:false});

lbContent.addEventListener('mousedown', e => {
    e.preventDefault(); dragging = true; moved = false;
    startX = e.clientX - offX; startY = e.clientY - offY;
});
lbContent.addEventListener('dragstart', e => e.preventDefault());
window.addEventListener('mousemove', e => {
    if(!dragging) return;
    const dx = e.clientX - startX, dy = e.clientY - startY;
    if(Math.abs(dx) > 3 || Math.abs(dy) > 3) moved = true;
    offX = dx; offY = dy; applyTransform();
});
window.addEventListener('mouseup', () => {
    if(dragging && !moved && scale > 1){ scale=1; offX=0; offY=0; applyTransform(); }
    dragging = false;
});

// ===== 卡片：原生loading=lazy =====
function makeCard(name){
    const card = document.createElement('div');
    card.className = 'gallery-item';
    if(isVideoName(name)){
        card.style.background = '#222';
        card.innerHTML = '<span style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);color:#fff;font-size:28px">▶</span>';
    }else{
        const img = document.createElement('img');
        img.src = thumbUrl(name);
        img.loading = 'lazy';
        card.appendChild(img);
    }
    card.onclick = () => openViewer(name);
    return card;
}

// ===== 索引图库：前端分页，每次渲染40张，滚动到底追加 =====
let allFiles = [], loadedIdx = 0;
const BATCH = 40;

async function loadIndex(reset){
    if(reset){
        const res = await fetch('/api/list');
        allFiles = await res.json();
        loadedIdx = 0;
        indexView.innerHTML = '';
    }
    if(loadedIdx >= allFiles.length) return;
    const end = Math.min(loadedIdx + BATCH, allFiles.length);
    for(let i = loadedIdx; i < end; i++){
        indexView.appendChild(makeCard(allFiles[i]));
    }
    loadedIdx = end;
}

window.addEventListener('scroll', () => {
    if(timelineView.style.display !== 'none') return;
    if(window.innerHeight + window.scrollY >= document.body.scrollHeight - 400){
        loadIndex(false);
    }
});

// ===== 时间线图库：全部展开，原生loading=lazy =====
let railHideTimer = null;
function buildRail(years){
    const rail = document.getElementById('timelineRail');
    rail.innerHTML = '';
    years.forEach(ym=>{
        const a = document.createElement('a');
        a.innerText = ym; a.href = 'javascript:void(0)';
        a.onclick = () => { const s = document.getElementById('tl-'+ym); if(s) s.scrollIntoView({behavior:'smooth'}); };
        rail.appendChild(a);
    });
}

async function loadTimeline(){
    const res = await fetch('/api/timeline');
    const groups = await res.json();
    timelineView.innerHTML = '';
    viewerList = [];
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
            viewerList.push(name);
            grid.appendChild(makeCard(name));
        });
        sec.appendChild(grid);
        timelineView.appendChild(sec);
    });
    buildRail(years);
}

function armRailHover(){
    document.onmousemove = e => {
        if(timelineView.style.display === 'none') return;
        const rail = document.getElementById('timelineRail');
        if(e.clientX > window.innerWidth - 24){
            rail.style.opacity = 1; clearTimeout(railHideTimer);
        }else if(e.clientX < window.innerWidth - 80){
            clearTimeout(railHideTimer);
            railHideTimer = setTimeout(()=>{ rail.style.opacity = 0; }, 3000);
        }
    };
}

const tabIndex = document.getElementById('tabIndex');
const tabTimeline = document.getElementById('tabTimeline');

function switchTab(which){
    const rail = document.getElementById('timelineRail');
    if(which === 'index'){
        indexView.style.display = '';
        timelineView.style.display = 'none';
        rail.style.opacity = 0;
        tabIndex.classList.add('active');
        tabTimeline.classList.remove('active');
    }else{
        indexView.style.display = 'none';
        timelineView.style.display = '';
        tabIndex.classList.remove('active');
        tabTimeline.classList.add('active');
        loadTimeline();
        armRailHover();
    }
}
tabIndex.onclick = () => switchTab('index');
tabTimeline.onclick = () => switchTab('timeline');

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
    uploadBtn.disabled = false; uploadBtn.innerText = '上传图片/视频';
    fileInput.value = '';
    loadIndex(true);
});

window.onload = () => loadIndex(true);
