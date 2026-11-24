# 歌词墙 LyricWall

3D 水面立体歌词墙，TrollStore IPA（原创，顾海龙集团）。

- 123 首歌、51 种水面风格，3D 立体墙原样显示
- 只看不放音乐（词照常走，不出声）
- 工具栏：下一首、换主题、搜索、随机一首
- 首次打开输入授权码激活（码表见 `license/codes-lyricwall.json`）

## 安装

运行 `./build.sh` 编出 IPA，用 TrollStore 安装，首次打开输入授权码激活。

## 编译

```sh
./build.sh    # 编包（Theos 工具链，Linux）
./verify.sh   # 验包
```

## 许可

MIT License，见 LICENSE。
