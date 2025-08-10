# Changelog

## [1.5.4](https://github.com/y3owk1n/time-machine.nvim/compare/v1.5.3...v1.5.4) (2025-08-10)


### Bug Fixes

* **ci:** move docs out to its own workflow ([#96](https://github.com/y3owk1n/time-machine.nvim/issues/96)) ([e59e15a](https://github.com/y3owk1n/time-machine.nvim/commit/e59e15ab54d0dd0e8bc0db7f7fd33a53c0ab7767))

## [1.5.3](https://github.com/y3owk1n/time-machine.nvim/compare/v1.5.2...v1.5.3) (2025-07-20)


### Bug Fixes

* **config:** make logger function private ([#93](https://github.com/y3owk1n/time-machine.nvim/issues/93)) ([78cc2e4](https://github.com/y3owk1n/time-machine.nvim/commit/78cc2e42ab2cf72af4a69a271e661d130641b93c))
* **docs:** switch doc gen from `pandocvim` to `vimcats` ([#91](https://github.com/y3owk1n/time-machine.nvim/issues/91)) ([924c3d7](https://github.com/y3owk1n/time-machine.nvim/commit/924c3d7fffca486ce3f7c71425e3064a8c43c8b1))
* remove whitespace ([#94](https://github.com/y3owk1n/time-machine.nvim/issues/94)) ([6f593a5](https://github.com/y3owk1n/time-machine.nvim/commit/6f593a50736507a6ffa11c2008109a250cb40f00))

## [1.5.2](https://github.com/y3owk1n/time-machine.nvim/compare/v1.5.1...v1.5.2) (2025-07-01)


### Bug Fixes

* **tree:** add different configurable `time_format` ([#88](https://github.com/y3owk1n/time-machine.nvim/issues/88)) ([66b173e](https://github.com/y3owk1n/time-machine.nvim/commit/66b173e7b6ddf58c79e124f945b8b4112b89f75e))
* **ui:** ensure pattern matching for time section matches new config ([#90](https://github.com/y3owk1n/time-machine.nvim/issues/90)) ([cf5e66a](https://github.com/y3owk1n/time-machine.nvim/commit/cf5e66ab02c132c4289f0b1ac65c52ba5a80a0c2))

## [1.5.1](https://github.com/y3owk1n/time-machine.nvim/compare/v1.5.0...v1.5.1) (2025-05-04)


### Bug Fixes

* **ui:** abort opening panel when no undos found ([#86](https://github.com/y3owk1n/time-machine.nvim/issues/86)) ([155bf71](https://github.com/y3owk1n/time-machine.nvim/commit/155bf71d8496c05fbc38ea732d4d711b21591afe))

## [1.5.0](https://github.com/y3owk1n/time-machine.nvim/compare/v1.4.2...v1.5.0) (2025-04-30)


### Features

* **highlights:** add `timeline_alt` for highlight overrides ([#77](https://github.com/y3owk1n/time-machine.nvim/issues/77)) ([5dbfaea](https://github.com/y3owk1n/time-machine.nvim/commit/5dbfaea60293454213ed9d3beccc6339b5fff5d6))
* **window:** add configurable `winblend` for floats ([#73](https://github.com/y3owk1n/time-machine.nvim/issues/73)) ([7fd8482](https://github.com/y3owk1n/time-machine.nvim/commit/7fd848272c72102e58a8e550147eb88b2a661f70))


### Bug Fixes

* **highlights:** ensure hl is overridable ([#76](https://github.com/y3owk1n/time-machine.nvim/issues/76)) ([08bda79](https://github.com/y3owk1n/time-machine.nvim/commit/08bda79dfc13b4b81d2fbb8295d0ad5a3a438d84))
* **icons:** rename icon names and use rounded corner ([#85](https://github.com/y3owk1n/time-machine.nvim/issues/85)) ([e3ea3ed](https://github.com/y3owk1n/time-machine.nvim/commit/e3ea3edbfa7339833375241c81c293e233220cee))
* **tree:** nicer connector for root node ([#78](https://github.com/y3owk1n/time-machine.nvim/issues/78)) ([70d03ac](https://github.com/y3owk1n/time-machine.nvim/commit/70d03acca7a485272441329409a800f40bb0c172))
* **ui.set_highlights:** remain actual hl for current text ([#83](https://github.com/y3owk1n/time-machine.nvim/issues/83)) ([36e858a](https://github.com/y3owk1n/time-machine.nvim/commit/36e858a000e8848920ed8726a4fd5e820094f9e0))
* **ui:** add padding before first icon node in timeline ([#82](https://github.com/y3owk1n/time-machine.nvim/issues/82)) ([abb52ab](https://github.com/y3owk1n/time-machine.nvim/commit/abb52ab3d7d2ddf2ed27654c4c204744ea24414b))
* **window.create_native_float_win:** ensure grabbing footer text keymap from config ([#75](https://github.com/y3owk1n/time-machine.nvim/issues/75)) ([6bdaa91](https://github.com/y3owk1n/time-machine.nvim/commit/6bdaa91185cf4e8f5f5efad7457a2d0b7f120aec))

## [1.4.2](https://github.com/y3owk1n/time-machine.nvim/compare/v1.4.1...v1.4.2) (2025-04-28)


### Bug Fixes

* **ui:** avoid reusing existing floats ([#69](https://github.com/y3owk1n/time-machine.nvim/issues/69)) ([ce03a29](https://github.com/y3owk1n/time-machine.nvim/commit/ce03a29977d751a90c8e4d760a5d1834bb3c35be))
* **utils:** allow optional bufnr and winid to close it ([#67](https://github.com/y3owk1n/time-machine.nvim/issues/67)) ([ffcd3be](https://github.com/y3owk1n/time-machine.nvim/commit/ffcd3beed1c6e93db4142f9800a63b3a0e5d27c9))
* **window.create_native_split_win:** eliminate orphaned empty buffer when creating split ([#71](https://github.com/y3owk1n/time-machine.nvim/issues/71)) ([77a5fd1](https://github.com/y3owk1n/time-machine.nvim/commit/77a5fd1686de336edaa7e5c10cc0f889d72117d1))

## [1.4.1](https://github.com/y3owk1n/time-machine.nvim/compare/v1.4.0...v1.4.1) (2025-04-28)


### Bug Fixes

* **config.setup_autocmds:** more checks to ensure not over-emitting `undo_created` event ([#63](https://github.com/y3owk1n/time-machine.nvim/issues/63)) ([a398221](https://github.com/y3owk1n/time-machine.nvim/commit/a3982213c41b93f77830266ac0a9a2f02f61d104))
* **diff.preview_diff_external:** add log for closing win ([#65](https://github.com/y3owk1n/time-machine.nvim/issues/65)) ([cb57e3a](https://github.com/y3owk1n/time-machine.nvim/commit/cb57e3acc7a8b913c69f2d79a9babf4dee246e91))
* log every event emission ([#66](https://github.com/y3owk1n/time-machine.nvim/issues/66)) ([18dfa6c](https://github.com/y3owk1n/time-machine.nvim/commit/18dfa6cce5de8fe7bd65bb6f3732deb9076a4121))

## [1.4.0](https://github.com/y3owk1n/time-machine.nvim/compare/v1.3.0...v1.4.0) (2025-04-28)


### Features

* add detailed loggers with configurations ([#60](https://github.com/y3owk1n/time-machine.nvim/issues/60)) ([349e1b9](https://github.com/y3owk1n/time-machine.nvim/commit/349e1b95f05cc586e87bd7a4d86e603dc4336e8d))


### Bug Fixes

* **actions.toggle:** do not notify if condition not met for toggling ([#57](https://github.com/y3owk1n/time-machine.nvim/issues/57)) ([501dfd1](https://github.com/y3owk1n/time-machine.nvim/commit/501dfd116d50451b7fc2527f041ad3484af56255))
* **config.setup_autocmds:** ignore time machine buffer for emitting `undo_created` event ([#62](https://github.com/y3owk1n/time-machine.nvim/issues/62)) ([287067a](https://github.com/y3owk1n/time-machine.nvim/commit/287067a9b1eaaaeccd750ad7f36401ac62e348f4))

## [1.3.0](https://github.com/y3owk1n/time-machine.nvim/compare/v1.2.2...v1.3.0) (2025-04-27)


### Features

* **diff:** support user defined args for external diff tools and configurable from config opts ([#47](https://github.com/y3owk1n/time-machine.nvim/issues/47)) ([2def5dc](https://github.com/y3owk1n/time-machine.nvim/commit/2def5dc1c8b24f393aef97ada53484da35189b41))


### Bug Fixes

* **diff.preview:** use configured close mapping to quit diff panel ([#49](https://github.com/y3owk1n/time-machine.nvim/issues/49)) ([b89cd28](https://github.com/y3owk1n/time-machine.nvim/commit/b89cd2868753409d9754aff3b8c666ff1bb86948))
* **ui.set_header:** only show undofile path when it is readable ([#46](https://github.com/y3owk1n/time-machine.nvim/issues/46)) ([f869ee4](https://github.com/y3owk1n/time-machine.nvim/commit/f869ee4f4cd1cf5dbc4796ec5c5d287c6c018047))
* **ui.set_highlights:** single buf_lines call and iterate with id ([#38](https://github.com/y3owk1n/time-machine.nvim/issues/38)) ([ce5ae16](https://github.com/y3owk1n/time-machine.nvim/commit/ce5ae169ea516c7837b999d29be3fb3584630a19))
* **ui:** send event `tags_created` and refresh via autocmd instead of manual ([#52](https://github.com/y3owk1n/time-machine.nvim/issues/52)) ([d8a608b](https://github.com/y3owk1n/time-machine.nvim/commit/d8a608b95bf274f77155455e141f8d775aed0c53))
* **ui:** send event `undo` and `redo` instead of manual refresh the UI ([#51](https://github.com/y3owk1n/time-machine.nvim/issues/51)) ([13bed56](https://github.com/y3owk1n/time-machine.nvim/commit/13bed56eba390c1eb19324e74054e296cf295824))


### Performance Improvements

* **diff.preview_diff_external:** validate executables before IO ([#42](https://github.com/y3owk1n/time-machine.nvim/issues/42)) ([4985430](https://github.com/y3owk1n/time-machine.nvim/commit/49854302ecfcbbe207407b60f77e3b51048d3db9))
* **diff.read_buffer_at_seq:** avoid manual window switching ([#43](https://github.com/y3owk1n/time-machine.nvim/issues/43)) ([8312dba](https://github.com/y3owk1n/time-machine.nvim/commit/8312dba1b6e74bf615a3588cb33f3cf924e13530))
* **diff.write_temp:** replace `vim.fn.writefile` with faster `vim.uv.fs` functions ([#44](https://github.com/y3owk1n/time-machine.nvim/issues/44)) ([ba9e42c](https://github.com/y3owk1n/time-machine.nvim/commit/ba9e42c35dc6746d6d7d2b5af3e50ca3a121b150))
* **ui:** cache looksup to reduce round trips ([#40](https://github.com/y3owk1n/time-machine.nvim/issues/40)) ([a86fa5e](https://github.com/y3owk1n/time-machine.nvim/commit/a86fa5e466f40b5116cfcb76fa443f2902a4fab7))

## [1.2.2](https://github.com/y3owk1n/time-machine.nvim/compare/v1.2.1...v1.2.2) (2025-04-26)


### Bug Fixes

* **actions.purge:** use `vim.ui.select` instead of `vim.fn.input` ([#32](https://github.com/y3owk1n/time-machine.nvim/issues/32)) ([f1be003](https://github.com/y3owk1n/time-machine.nvim/commit/f1be003d0fac1f7c40dafabd8659b7a6b9920729))
* **actions.restore:** ensure to early return if no `content_bufnr` found ([#36](https://github.com/y3owk1n/time-machine.nvim/issues/36)) ([355488e](https://github.com/y3owk1n/time-machine.nvim/commit/355488e2ec2a9511fbbf76592c6d2cf898a8d6e5))
* **actions.toggle:** ensure checking for time machine buf for proper toggling ([#30](https://github.com/y3owk1n/time-machine.nvim/issues/30)) ([14b7e53](https://github.com/y3owk1n/time-machine.nvim/commit/14b7e53c9d9323380a7e400a6195ce318de1db35))
* **ui.set_header:** check if `tags_path` actually exists before creating it's header line ([#37](https://github.com/y3owk1n/time-machine.nvim/issues/37)) ([563c755](https://github.com/y3owk1n/time-machine.nvim/commit/563c75520c60600e3ee20a3922022cbff7d03852))
* **undotree.refresh_buffer_window:** reorder re-attachment of refreshed buffer window ([#35](https://github.com/y3owk1n/time-machine.nvim/issues/35)) ([150bcb1](https://github.com/y3owk1n/time-machine.nvim/commit/150bcb1ae0bead71c91a62ba1669ffcb31d60938))
* **undotree.remove_undo_file:** do not try to refresh buffer if failed to remove undofile ([#34](https://github.com/y3owk1n/time-machine.nvim/issues/34)) ([f9dcbbe](https://github.com/y3owk1n/time-machine.nvim/commit/f9dcbbedfd064c65d68559de44873ea18e9dca01))

## [1.2.1](https://github.com/y3owk1n/time-machine.nvim/compare/v1.2.0...v1.2.1) (2025-04-26)


### Bug Fixes

* **diff.preview_diff_external:** early return and pcall on diff cmds ([#29](https://github.com/y3owk1n/time-machine.nvim/issues/29)) ([3d76354](https://github.com/y3owk1n/time-machine.nvim/commit/3d763547c358480503c998584ea88d45974a3cf3))
* **healthcheck:** add delta to healthcheck ([#27](https://github.com/y3owk1n/time-machine.nvim/issues/27)) ([c4fa2e1](https://github.com/y3owk1n/time-machine.nvim/commit/c4fa2e1153659e29d180cb7cd41dcf4eb0261120))

## [1.2.0](https://github.com/y3owk1n/time-machine.nvim/compare/v1.1.0...v1.2.0) (2025-04-26)


### Features

* **config:** add usercmd for actions ([#22](https://github.com/y3owk1n/time-machine.nvim/issues/22)) ([d4b2d41](https://github.com/y3owk1n/time-machine.nvim/commit/d4b2d41043f0f3412615b9759c92974f5bfd759b))
* **diff:** add `delta` support ([#23](https://github.com/y3owk1n/time-machine.nvim/issues/23)) ([e470fad](https://github.com/y3owk1n/time-machine.nvim/commit/e470fad0b9958c30ba38e7258fdd306e9c6b9c3b))
* **ui:** add `undo` and `redo` keymaps ([#19](https://github.com/y3owk1n/time-machine.nvim/issues/19)) ([b2cad9d](https://github.com/y3owk1n/time-machine.nvim/commit/b2cad9dfd612c28e5095575bae413dad4cb64d8d))


### Bug Fixes

* **actions.toggle:** skip unnamed and unlisted buffers ([#26](https://github.com/y3owk1n/time-machine.nvim/issues/26)) ([cbe4f70](https://github.com/y3owk1n/time-machine.nvim/commit/cbe4f7098573eaf5ac7dc109d29d78e3f267789d))
* **ui:** rename `main timeline` to `current timeline` that makes more sense ([#25](https://github.com/y3owk1n/time-machine.nvim/issues/25)) ([d1be672](https://github.com/y3owk1n/time-machine.nvim/commit/d1be672142757bdbfdc005be1248c847bacf2595))

## [1.1.0](https://github.com/y3owk1n/time-machine.nvim/compare/v1.0.0...v1.1.0) (2025-04-26)


### Features

* **config:** make keymaps configurable ([#13](https://github.com/y3owk1n/time-machine.nvim/issues/13)) ([7c91087](https://github.com/y3owk1n/time-machine.nvim/commit/7c910874e82830707d538b916787bf0c07198694))
* **ui:** add toggleable timeline view ([#15](https://github.com/y3owk1n/time-machine.nvim/issues/15)) ([7b3c1ab](https://github.com/y3owk1n/time-machine.nvim/commit/7b3c1abcd13bab1665dd54029ce97db2e5a26995))
* **ui:** make float size configurable ([#17](https://github.com/y3owk1n/time-machine.nvim/issues/17)) ([96d4114](https://github.com/y3owk1n/time-machine.nvim/commit/96d411410a9cd6cb33707c94ca739b94008c64e9))


### Bug Fixes

* **ui:** add annotation for the main timeline ([#11](https://github.com/y3owk1n/time-machine.nvim/issues/11)) ([06971b3](https://github.com/y3owk1n/time-machine.nvim/commit/06971b35858a8f849c8faac47546ed04484cc9ff))
* **ui:** add highlights to current timeline icon ([#9](https://github.com/y3owk1n/time-machine.nvim/issues/9)) ([500ce6f](https://github.com/y3owk1n/time-machine.nvim/commit/500ce6f7e9beb30b5efdced0b97e99002424c69d))
* **ui:** declutter header keymaps ui ([#12](https://github.com/y3owk1n/time-machine.nvim/issues/12)) ([c203de0](https://github.com/y3owk1n/time-machine.nvim/commit/c203de04eafa8815b4c00bbb3a789574b2d52dce))
* **ui:** force main timeline to always have separator ([#16](https://github.com/y3owk1n/time-machine.nvim/issues/16)) ([0588c3b](https://github.com/y3owk1n/time-machine.nvim/commit/0588c3b4249d00614ec5b09b6e44da56a169c71f))

## 1.0.0 (2025-04-25)


### Features

* add config toggle for save_on_buf_read and save_on_write ([9b9de66](https://github.com/y3owk1n/time-machine.nvim/commit/9b9de66e140ad0dfdefbc02afec6b473d7f8a643))
* add diff preview ([0f1f65c](https://github.com/y3owk1n/time-machine.nvim/commit/0f1f65c5915c82ae4f248c7aa3ac9ea36880549b))
* add diff_opts to config ([368681f](https://github.com/y3owk1n/time-machine.nvim/commit/368681f261a3c3188a14d9ddd4cbdbcc6048356a))
* add difft initial ([d1210ac](https://github.com/y3owk1n/time-machine.nvim/commit/d1210ac4e52a527a07f5833f4242ef293d49d93f))
* add healthcheck ([8f22c41](https://github.com/y3owk1n/time-machine.nvim/commit/8f22c41654540d13148f8bf2d62a081eafbeed58))
* add ignore undo for filesize ([47e0adf](https://github.com/y3owk1n/time-machine.nvim/commit/47e0adf120665faa7d800e6897348dad6cb0d5c7))
* **ci:** add ci action ([#5](https://github.com/y3owk1n/time-machine.nvim/issues/5)) ([f7c9a27](https://github.com/y3owk1n/time-machine.nvim/commit/f7c9a270a94b7ab404a6fea15cd675762d651158))
* **ci:** add release-please ([#2](https://github.com/y3owk1n/time-machine.nvim/issues/2)) ([18d8aa3](https://github.com/y3owk1n/time-machine.nvim/commit/18d8aa38428a318cd3d2ab3de91b2e3ec5423a6f))
* close ui event ([82bdd7f](https://github.com/y3owk1n/time-machine.nvim/commit/82bdd7f3f673fa7b2d61f07faf8eb33a167bdf18))
* first version ([4fe0870](https://github.com/y3owk1n/time-machine.nvim/commit/4fe087009268b2ba14c061218e44874b071c028d))
* initial move to undofiles ([#1](https://github.com/y3owk1n/time-machine.nvim/issues/1)) ([6f89f25](https://github.com/y3owk1n/time-machine.nvim/commit/6f89f25472db4239a1ae1297e06b107d0d180d6f))
* initial support for tags ([df23eab](https://github.com/y3owk1n/time-machine.nvim/commit/df23eab5a660a5adebe12a7e43955d4aaa9657e4))
* partial buf based sqlite implementation ([33c5fcd](https://github.com/y3owk1n/time-machine.nvim/commit/33c5fcd6867fc7072512dcb005c09a0b69ef1693))
* purging also remove tag files ([2c098dd](https://github.com/y3owk1n/time-machine.nvim/commit/2c098dd2cd5bf8e23699ff0fa507b054cb5bba1a))
* setup highlights ([d277f2d](https://github.com/y3owk1n/time-machine.nvim/commit/d277f2d58443d1ea147693b2567c03c54487e1eb))
* support difftastic ([a57988c](https://github.com/y3owk1n/time-machine.nvim/commit/a57988c777a9e27d3ad960f1317d67043ae7551d))
* **ui:** add tagging on dashboard ([2642345](https://github.com/y3owk1n/time-machine.nvim/commit/2642345fc52a94ea15e730dab929dca766b42832))
* update autorefresh and autosave ([42038b5](https://github.com/y3owk1n/time-machine.nvim/commit/42038b5263fae4e0f650ac51f74c4b28cbd3e089))


### Bug Fixes

* **actions:** ensure tags[] are properly inserted ([830a0bf](https://github.com/y3owk1n/time-machine.nvim/commit/830a0bf8be7f13a915903a39d8aebca8893a7636))
* add configurable split opts for tree ui ([d27c243](https://github.com/y3owk1n/time-machine.nvim/commit/d27c243db203a25a9aa4e3c243f9a1c5c4fa90e6))
* add g? and keymap hints ([75132c4](https://github.com/y3owk1n/time-machine.nvim/commit/75132c443a9f4ce99c01ffed72451c5200cd4f31))
* add missing keymap to help ([4382e63](https://github.com/y3owk1n/time-machine.nvim/commit/4382e63160de89499388d372154117ecf1dd3ed2))
* add more info in snapshot list ([75bd5c6](https://github.com/y3owk1n/time-machine.nvim/commit/75bd5c696002530c2f9279d209380963ceccca34))
* add more keymaps ([6794d00](https://github.com/y3owk1n/time-machine.nvim/commit/6794d00d65ccc29024fb7f1750318bec074a0bfb))
* add persistent status ([9e6298e](https://github.com/y3owk1n/time-machine.nvim/commit/9e6298ea3d68a3490a4a78b3e8336f9ee1576bec))
* add types annotation ([0691b9a](https://github.com/y3owk1n/time-machine.nvim/commit/0691b9ad741bf13d071e91989b7f701b173bf4c8))
* another improvement for tree UI ([c3722b1](https://github.com/y3owk1n/time-machine.nvim/commit/c3722b150aadd746f31ba689f4aaf9c2f55a736c))
* auto close snapshot list ([ed34ce0](https://github.com/y3owk1n/time-machine.nvim/commit/ed34ce02b7284d5cb4dd581ab0dc2b4c2de2d686))
* better buffer options ([91cba19](https://github.com/y3owk1n/time-machine.nvim/commit/91cba1925356fb4ec1a76c782b92e64c4bf779ee))
* check also if id is empty string during handling restore ([01f4c8c](https://github.com/y3owk1n/time-machine.nvim/commit/01f4c8cdf8e8808c5da0b2ad16e6852ba124213a))
* cleanup ([80d95ff](https://github.com/y3owk1n/time-machine.nvim/commit/80d95ffcc6244df4bd25e55adcbf86a88334a01c))
* cleanup ([90ab9a3](https://github.com/y3owk1n/time-machine.nvim/commit/90ab9a31ef4d884e61ed27a0d704c7400f4588e0))
* cleanup actions ([3759e5d](https://github.com/y3owk1n/time-machine.nvim/commit/3759e5d178250d78a309d152ebb83b16293f7f2a))
* cleanup config ([8350f09](https://github.com/y3owk1n/time-machine.nvim/commit/8350f0995c0443c6c4609ea6625b14beb7eb0483))
* cleanup diff ([f753809](https://github.com/y3owk1n/time-machine.nvim/commit/f75380989b92cc0a6a1de02e9aeb793ba9d2e410))
* cleanup removed configs ([ff9ce6f](https://github.com/y3owk1n/time-machine.nvim/commit/ff9ce6f9daf608b1da1897c2eb3276d8fe50e317))
* cleanup tags ([5b6e182](https://github.com/y3owk1n/time-machine.nvim/commit/5b6e182c9da65716634f5dc2e510aab52b7df605))
* cleanup ui ([f853281](https://github.com/y3owk1n/time-machine.nvim/commit/f853281e493968968af602227d914a2f3b8e0a80))
* cleanup undotree ([28e4256](https://github.com/y3owk1n/time-machine.nvim/commit/28e425610c8f4f5e21c79eb393558620115b6f36))
* cleanup unused buf_path ([874c1f5](https://github.com/y3owk1n/time-machine.nvim/commit/874c1f5bef0503b815c885909a11c6479a01cad4))
* cleanup utils ([7906337](https://github.com/y3owk1n/time-machine.nvim/commit/790633775cc2449bd6fe87a7fcfd39bc99cf673c))
* decoding sequence ([059003e](https://github.com/y3owk1n/time-machine.nvim/commit/059003e60fd18d660a562f6398757dc06077783a))
* do not purge if persistent is off ([7ea1328](https://github.com/y3owk1n/time-machine.nvim/commit/7ea1328ba375c222787c9fef254c629441adc1a6))
* do not run remove_undofile again in purge_all ([c2918ab](https://github.com/y3owk1n/time-machine.nvim/commit/c2918abef2873559856c1cd5bf1f03512ff368b3))
* ensure content and diff are loaded last to prevent parsing error ([a373f83](https://github.com/y3owk1n/time-machine.nvim/commit/a373f830035988a5b59e7091a5771e1771ecdec1))
* ensure to pass `silent` from autocmd to create_snapshot ([39c5143](https://github.com/y3owk1n/time-machine.nvim/commit/39c5143ba893519180b7a9913436e09ce010e3c2))
* fetch minimal data as possible for actions ([d80711f](https://github.com/y3owk1n/time-machine.nvim/commit/d80711ff56a07296de288c5264006546cb690536))
* format files & bug ([#4](https://github.com/y3owk1n/time-machine.nvim/issues/4)) ([eb1bd05](https://github.com/y3owk1n/time-machine.nvim/commit/eb1bd05306658979797cc3e947ab18bb69c57df6))
* handle tagging input abort ([190fa02](https://github.com/y3owk1n/time-machine.nvim/commit/190fa02dba0e59ea44a821038e32c0b058e58a1d))
* highlights ([8310511](https://github.com/y3owk1n/time-machine.nvim/commit/83105118e3402faba91259fd35f0f6e8ec4e2445))
* improved tree formatting ([c906c9f](https://github.com/y3owk1n/time-machine.nvim/commit/c906c9f9b9cc32890cac9121c6df061817a85eb1))
* just return root if no git branch found ([5356381](https://github.com/y3owk1n/time-machine.nvim/commit/5356381a43c5bf72fe92fa019a601b42141f3316))
* make colors looks better ([6fee6c7](https://github.com/y3owk1n/time-machine.nvim/commit/6fee6c723422dc5efbf3a4aa927e722e84be55c7))
* make current highlight full_edge ([488ddd9](https://github.com/y3owk1n/time-machine.nvim/commit/488ddd9314df46b1b52743bfb20d9ebeef92c410))
* make split fixed ([36b6642](https://github.com/y3owk1n/time-machine.nvim/commit/36b66427796c7797ef46b8feabf8982ba2a084fc))
* make sure to close preview buf ([8fa2737](https://github.com/y3owk1n/time-machine.nvim/commit/8fa2737e0787f5d17a3c1d343e3ce3aa385b8d3d))
* make sure to decode when diffing ([88c6da3](https://github.com/y3owk1n/time-machine.nvim/commit/88c6da3423627ed3c48f8c87358478353c766570))
* make sure to set current snapshot after create ([e6ed25c](https://github.com/y3owk1n/time-machine.nvim/commit/e6ed25c5559dc5293c541adc75926b7bcf7c26b3))
* make sure to use constant ([1bd8cd8](https://github.com/y3owk1n/time-machine.nvim/commit/1bd8cd85189c1801a919e8b53e944061d82dea83))
* make toggleable panel ([682b8f7](https://github.com/y3owk1n/time-machine.nvim/commit/682b8f7fd409c85c1c2c8c3315ad061695dbee2b))
* make tree panel more minimal ([c4dcfc2](https://github.com/y3owk1n/time-machine.nvim/commit/c4dcfc2ab9127a00e9c8094c603cdb7dd51d54ef))
* merge ignored filetypes config ([e2fa94b](https://github.com/y3owk1n/time-machine.nvim/commit/e2fa94ba9b7617c173be8375fbbf358b608b3e56))
* more colors for each sequence ([6023146](https://github.com/y3owk1n/time-machine.nvim/commit/602314623cc23ee34439d3ab12ae015ce5464af6))
* move some db calls to async job ([2de5ef4](https://github.com/y3owk1n/time-machine.nvim/commit/2de5ef43ab4459217f6884788bfb048249ccff77))
* name is required ([52f259c](https://github.com/y3owk1n/time-machine.nvim/commit/52f259ca395cf803fd0c513fc7ea161fc4cb3f61))
* only allow tagging if enabled persistent undo ([2b8f8e8](https://github.com/y3owk1n/time-machine.nvim/commit/2b8f8e82172f5dc16b308e2bf79448a758cc9be2))
* only allow to preview_snapshot within boundary ([f1dcf01](https://github.com/y3owk1n/time-machine.nvim/commit/f1dcf013505116404c073b2c2b8c234340d0a938))
* only lines that has seq is taggable ([b40873e](https://github.com/y3owk1n/time-machine.nvim/commit/b40873e3e1952ead83d23a32c3b1c07493d50b1e))
* preview with only current diff ([70fd213](https://github.com/y3owk1n/time-machine.nvim/commit/70fd2132c24fbfa106ece339dbc8a3e3e2876020))
* properly detect winid for smarter toggling ([3c840f5](https://github.com/y3owk1n/time-machine.nvim/commit/3c840f5e2064aba2eeb00445e7a128f3e41927a9))
* properly refresh when switching undos ([fe31292](https://github.com/y3owk1n/time-machine.nvim/commit/fe31292d4752ac6be2101f03be0f680c751a563b))
* refactor get_short_id ([1dddcfa](https://github.com/y3owk1n/time-machine.nvim/commit/1dddcfa2a410ed9ffe3f2f52d83db708a6b628ed))
* remove binary checks ([e246ec8](https://github.com/y3owk1n/time-machine.nvim/commit/e246ec8fe104ad210f01b7673de1087c717c995e))
* remove branching out mechanism ([c739784](https://github.com/y3owk1n/time-machine.nvim/commit/c73978410dba0f651d1fceb1310504ca0c23ae34))
* remove current icon and just highlight the line ([76d6cd8](https://github.com/y3owk1n/time-machine.nvim/commit/76d6cd8c83ceedc4ca03fd47628999fefebc0059))
* remove prune for now ([2039f34](https://github.com/y3owk1n/time-machine.nvim/commit/2039f34f4bf1383297baac26a1a66c65477d4e14))
* remove telescope implementation ([0cf9035](https://github.com/y3owk1n/time-machine.nvim/commit/0cf9035a38664023e275d9e11e2bcbcec16cfb5e))
* remove the buf when close instead of just hide the window ([5a790f1](https://github.com/y3owk1n/time-machine.nvim/commit/5a790f154b1793b2b8f09954029a91c9a0906d9e))
* rename to `snapshot_ft` ([2b3c711](https://github.com/y3owk1n/time-machine.nvim/commit/2b3c7119cdc6d672488d17bce76b7c38608db0a1))
* rename variable undotree to ut ([841588c](https://github.com/y3owk1n/time-machine.nvim/commit/841588cc864ee5032f3d77101722d1c20675efb5))
* reverse the snapshot graph, root at bottom to top ([40f4c17](https://github.com/y3owk1n/time-machine.nvim/commit/40f4c17fdd2e166213adf5c15da21fd5e903a3e1))
* set current cursor to the current seq when toggle ([3237585](https://github.com/y3owk1n/time-machine.nvim/commit/32375854b56f7ceed7aab270aceaca8793e7909c))
* standardize snapshot naming from history ([c3356a5](https://github.com/y3owk1n/time-machine.nvim/commit/c3356a5f47fb6767e69f1205b5836b740c82794d))
* swap old and new lines for diff ([dde2f84](https://github.com/y3owk1n/time-machine.nvim/commit/dde2f84c3f6d3a6ff599372a1758887a4a26d36f))
* typo ([e902adc](https://github.com/y3owk1n/time-machine.nvim/commit/e902adc25254e00923553d8306672f399e8fe4d1))
* **ui:** allow to pass title to floating window ([a16c3c7](https://github.com/y3owk1n/time-machine.nvim/commit/a16c3c755c56fca0a0b4eff18762790ca1360dcc))
* **ui:** finally my desired graph ([0b5c0f3](https://github.com/y3owk1n/time-machine.nvim/commit/0b5c0f3740595bbc3fa47eaafa9ecfb631fb214e))
* **ui:** slighty improve format_tree ([29b5774](https://github.com/y3owk1n/time-machine.nvim/commit/29b57740921391ddf7cf67ddfb5e3ee911c15ac7))
* **ui:** update annotation for legends ([a85d611](https://github.com/y3owk1n/time-machine.nvim/commit/a85d611c6ae75602cee6879ee15bb5575bb51cef))
* **ui:** use graph instead of tree and properly update the history when refresh ([0dc89f9](https://github.com/y3owk1n/time-machine.nvim/commit/0dc89f97f9f3b33534055cdcee95362992337af8))
* update ui message ([f13e352](https://github.com/y3owk1n/time-machine.nvim/commit/f13e352e982096fdc30ced967c8b49a5846bd78d))
* use alternative separator instead of "|" ([6396751](https://github.com/y3owk1n/time-machine.nvim/commit/6396751075b1d5442e721b59db29134d549f4294))
* use existing get_undofile function ([f20f1f3](https://github.com/y3owk1n/time-machine.nvim/commit/f20f1f36cc1263b36530552aa06d1d8266fa627d))
* use filetypes insetad of buftypes ([2535b26](https://github.com/y3owk1n/time-machine.nvim/commit/2535b2637f92114969fd57c818f05af421242508))
* use insertleave instead of textchangedI ([bb61309](https://github.com/y3owk1n/time-machine.nvim/commit/bb6130984da4444fabe13a78ce5cd0803386886e))
* use syntax to highlight different file but set ft to `time-machine-list` ([86395c5](https://github.com/y3owk1n/time-machine.nvim/commit/86395c5d9793f389d684fd26796e058c814f55ec))
* use UUID instead to get better IDs ([3cc9c5d](https://github.com/y3owk1n/time-machine.nvim/commit/3cc9c5d72401083ea63f3778052131a44c8413cb))
