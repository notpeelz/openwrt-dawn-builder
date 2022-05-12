ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS openwrt-builder

ARG MAKE_ARGS=

COPY config.buildinfo .config

RUN ./scripts/feeds update -a && ./scripts/feeds install -a

FROM openwrt-builder AS toolchain

RUN echo "CONFIG_DEVEL=y" >> .config \
  && echo "CONFIG_SRC_TREE_OVERRIDE=y" >> .config \
  && echo "CONFIG_PACKAGE_dawn=m" >> .config
RUN make defconfig

ARG TOOLCHAIN_MAKE_ARGS=
RUN make ${MAKE_ARGS} ${TOOLCHAIN_MAKE_ARGS} toolchain/install

FROM toolchain

ARG REPO_URL
RUN git clone "$REPO_URL" /dawn \
  && ln -s /dawn/.git ./feeds/packages/net/dawn/git-src

ARG DAWN_MAKE_ARGS=
RUN make package/dawn/clean \
  && make ${MAKE_ARGS} ${DAWN_MAKE_ARGS} package/dawn/compile
