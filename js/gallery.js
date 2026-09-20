/**
 * 相册前端逻辑
 * 基础版：从 /api/images 获取图片列表并渲染
 * 若后端不可用，则回退到手动配置的图片列表
 */

// 手动配置的图片列表（作为回退，实际部署时图片放在挂载的 img 目录）
const FALLBACK_IMAGES = [
  "img/photo1.jpg",
  "img/photo2.jpg",
  "img/photo3.jpg"
];

const galleryEl = document.getElementById("gallery");
const lightbox = document.getElementById("lightbox");
const lightboxImg = document.getElementById("lightboxImg");
const closeBtn = document.getElementById("closeBtn");

/**
 * 初始化相册
 */
async function initGallery() {
  let images = [];

  // 尝试从后端 API 获取图片列表（后续迭代会加上）
  try {
    const resp = await fetch("/api/images");
    if (resp.ok) {
      const data = await resp.json();
      images = data.images || [];
    }
  } catch (e) {
    // API 不可用，使用回退列表
    console.log("API 不可用，使用静态图片列表");
  }

  // 如果 API 没有返回图片，使用回退列表
  if (images.length === 0) {
    images = FALLBACK_IMAGES;
  }

  renderGallery(images);
}

/**
 * 渲染相册网格
 */
function renderGallery(images) {
  galleryEl.innerHTML = "";

  if (images.length === 0) {
    galleryEl.innerHTML = `
      <div class="empty-state">
        <h2>暂无图片</h2>
        <p>请将图片放入服务器的图片目录中</p>
      </div>
    `;
    return;
  }

  images.forEach(src => {
    const div = document.createElement("div");
    div.className = "gallery-item";
    div.innerHTML = `<img src="${src}" alt="photo" loading="lazy">`;
    div.onclick = () => openLightbox(src);
    galleryEl.appendChild(div);
  });
}

/**
 * 打开预览弹窗
 */
function openLightbox(src) {
  lightboxImg.src = src;
  lightbox.style.display = "block";
  document.body.style.overflow = "hidden";
}

/**
 * 关闭预览弹窗
 */
function closeLightbox() {
  lightbox.style.display = "none";
  lightboxImg.src = "";
  document.body.style.overflow = "";
}

// 事件绑定
closeBtn.onclick = closeLightbox;
lightbox.onclick = (e) => {
  if (e.target === lightbox) closeLightbox();
};
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && lightbox.style.display === "block") {
    closeLightbox();
  }
});

// 启动
initGallery();
