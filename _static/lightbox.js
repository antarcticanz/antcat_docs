document.addEventListener('DOMContentLoaded', function () {
  document.querySelectorAll('figure.zoomable-fig img').forEach(function (img) {
    img.style.cursor = 'zoom-in';

    var wrap = document.createElement('span');
    wrap.style.cssText = 'position:relative;display:inline-block;width:100%;';
    img.parentNode.insertBefore(wrap, img);
    wrap.appendChild(img);

    var badge = document.createElement('span');
    badge.innerHTML = '&#128269;';
    badge.title = 'Click to open full size';
    badge.style.cssText =
      'position:absolute;bottom:8px;right:8px;background:rgba(0,0,0,0.45);' +
      'color:#fff;border-radius:50%;width:32px;height:32px;font-size:1rem;' +
      'display:flex;align-items:center;justify-content:center;pointer-events:none;';
    wrap.appendChild(badge);

    img.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      window.open(img.src, '_blank', 'noopener');
    });

    // Also intercept the parent <a> if Sphinx wrapped the image in one
    var parent = img.closest('a');
    if (parent) {
      parent.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        window.open(img.src, '_blank', 'noopener');
      });
    }
  });
});
