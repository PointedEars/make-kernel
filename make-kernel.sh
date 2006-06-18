cd linux \
  && (make xconfig || make menuconfig || make config) \
  && export CONCURRENCY_LEVEL=4 \
  && fakeroot make-kpkg clean \
  && fakeroot make-kpkg --append-to-version -`date +%Y%m%d.%H%M%S%z` kernel_image modules_image
