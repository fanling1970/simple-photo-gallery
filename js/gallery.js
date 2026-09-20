function getCookie(name){
    const arr = document.cookie.match(new RegExp("(^| )"+name+"=([^;]*)(;|$)"));
    if(arr != null) return decodeURIComponent(arr[2]);
    return null;
}
document.getElementById("curUser").innerText = getCookie("token") || "";

const galleryEl = document.getElementById('gallery');
const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightboxImg');
const closeBtn = document.getElementById('closeBtn');
const fileInput = document.getElementById('fileInput');
const uploadBtn = document.getElementById('uploadBtn');

closeBtn.addEventListener('click', () => lightbox.style.display='none');
lightbox.addEventListener('click', e => { if(e.target===lightbox) lightbox.style.display='none'; });

async function loadImages(){
    try{
        const res = await fetch('/api/list');
        const files = await res.json();
        galleryEl.innerHTML = "";
        files.forEach(name => {
            const card = document.createElement('div');
            card.className = "gallery-item";
            const img = document.createElement('img');
            const thumbUrl = 'photos/images/thumb/' + encodeURIComponent(name);
            const fullUrl  = 'photos/images/' + encodeURIComponent(name);
            img.src = thumbUrl;
            img.loading = "lazy";
            img.onerror = () => { img.src = fullUrl; };  // 没有缩略图就直接显示原图
            card.appendChild(img);
            card.onclick = () => { lightboxImg.src = fullUrl; lightbox.style.display='flex'; };
            galleryEl.appendChild(card);
        });
        if(files.length === 0)
            galleryEl.innerHTML = '<p style="color:#aaa;text-align:center;width:100%">暂无图片，点击右上角「上传图片」</p>';
    }catch(e){
        galleryEl.innerHTML = '<p style="color:#f87171;text-align:center;width:100%">加载失败: '+e.message+'</p>';
    }
}

uploadBtn.addEventListener('click', () => fileInput.click());
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
    loadImages();
});

window.onload = loadImages;
