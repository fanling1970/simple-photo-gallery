// js/gallery.js
// 获取Cookie工具函数
function getCookie(name){
    const arr = document.cookie.match(new RegExp("(^| )"+name+"=([^;]*)(;|$)"));
    if(arr != null) return unescape(arr[2]);
    return null;
}
// 页面右上角显示当前登录用户名
document.getElementById("curUser").innerText = getCookie("token");

// ========== 原有相册图片加载逻辑占位，后续完善图片扫描渲染 ==========
const galleryEl = document.getElementById('gallery');
const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightboxImg');
const closeBtn = document.getElementById('closeBtn');

// 关闭预览弹窗
closeBtn.addEventListener('click', () => {
    lightbox.style.display = 'none';
});
lightbox.addEventListener('click', (e) => {
    if(e.target === lightbox) lightbox.style.display = 'none';
});

// 渲染图片列表函数（后续对接后端读取图片/缩略图）
function renderImages(imgList) {
    galleryEl.innerHTML = "";
    imgList.forEach(src => {
        const card = document.createElement('div');
        card.className = "gallery-item";
        card.innerHTML = `<img src="${src}" loading="lazy">`;
        card.onclick = () => {
            lightboxImg.src = src;
            lightbox.style.display = "flex";
        }
        galleryEl.appendChild(card);
    })
}

// 页面加载，后续在这里调用接口拉取图片列表
window.onload = function(){
    // renderImages([]);
}
