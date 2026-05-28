这是一个为 **ComputerCraft（CC）外设系统** 编写的 Lua 模拟框架，允许你在不依赖 Minecraft 环境的情况下，创建和测试带有物品容器、流体储罐等组件的虚拟外设。

---

# A546 Fake Peripheral Framework

一个轻量级的 ComputerCraft 外设模拟框架，用于在纯 Lua 环境中构建和测试虚拟外设及其交互逻辑。

## 提供的模块

- **虚拟外设容器** (`VirtualPeripheral`)：组装包含多个组件的虚拟外设，自动生成唯一名称
- **本地外设网络** (`LocalNet`)：管理外设网络，模拟 CC 的外设网络
- **物品容器组件** (`Inventory`)：模拟 CC 的通用库存外设（Inventory），支持设置槽位总数、存储系数
- **物品模块** (`Inventory.FakeItem`): 模拟 Minecraft 中的物品
- **流体储罐组件** (`tank`)：模拟通用流体存储外设（fluid_storage），支持设置多槽位、多流体类型、储罐存储上限
- **流体模块** (`tank.FakeFluid`): 模拟 Minecraft 中的流体
- **Peripheral API 模拟** (`peripheral`)：提供与 CC 几乎一致的 `peripheral.wrap`、`peripheral.find`、`peripheral.call` 等 API，加载模块时自动注入到全局环境

## 如何使用

### 物品与流体创建

你可以像这样创建物品和流体

```lua
local FakeItem = require("FakeContainerPeripheral").FakeItem
local FakeFluid = require("FakeContainerPeripheral").FakeFluid
local stone = FakeItem.make("minecraft:stone", 64, {})
local water = FakeFluid.make("minecraft:water")
```

`FakeItem.make`有三个参数，`name`、`stackLimit`以及`nbt`，而`FakeFluid`只有一个参数`name`。

由于代码结构问题，你在使用以及创建时需要注意以下几点：

- 尽可能只创建同一（`name`相同）物品、流体一次 ;
- 除非你知道自己在做什么，否则不要修改创建后的物品、流体中的字段；

### 创建外设组件

该模块提供了`tank`和`Inventory`模块，下面以这两种模块为例讲解。

```lua
local Inventory = require("FakeContainerPeripheral").Inventory
local tank = require("FakeContainerPeripheral").tank
local inv = Inventory.make(28, 1)
local tan = tank.make(4, 1, {1000, 1000, 1000, 1000})
local addItemCount = inv.dev:addItem(stone, 64, 1)
local removedItem, removedCount = inv.dev:removeItem(1, 32)
local addFluidAmount = tan.dev:addFluid(water, 1000)
local removedFluid, removedAmount = tan.dev:removeFluid(water.name, 500)
```

你可以通过`Inventory.make`的`size`和`storageCoefficient`参数来指定库存外设组件的槽位总数和堆叠系数（单槽位可存储物品数 = 存储系数 * 该槽位物品堆叠上限）；可以通过`tank.make`的`size`、`storageCoefficient`参数指定流体存储外设组件的储罐总数和存储系数，通过`capacityList`参数指定每个储罐的容量上限。

如你所见，创建好的`tank`以及`Inventory`都有一个`dev`字段，你可通过这个字段中的方法向外设组件添加物品或流体。这些方法的返回值在此不再赘述。

由于代码结构问题，你在使用以及创建时需要注意以下几点：

- 除非你知道你在做什么，否则不要通过`dev`字段提供的函数以外的方式修改创建好的外设组件；
- 在创建流体存储外设组件时，**`#capacityList`必须等于`size`**；

### 组装虚拟外设

```lua
local VirtualPeripheral = require("FakeContainerPeripheral").VirtualPeripheral
local chest = VirtualPeripheral.make("chest", inv)
local bottle = VirtualPeripheral.make("bottle", tan)

-- 或者
--[[
local backpack = VirtualPeripheral.make("backpack", inv, tan)
]]
```
`VirtualPeripheral.make`函数的参数信息可自行查看相关文件。

由于代码结构问题，你在使用以及创建时需要注意以下几点：

- 一个外设组件在被用于组装虚拟外设后不应该再被用于组装另一个虚拟外设；
- 一个虚拟外设在组装时如果输入多个同类型（`type`字段相同）的外设组件，只有一个外设组件会被用于组装虚拟外设，多余的外设组件会被忽略；
- 除非你知道自己在做什么，不要修改创建好的虚拟外设；

### 虚拟本地网络与添加外设

你可以像这样创建一个虚拟本地网络：

```lua
local LocalNet = require("FakeContainerPeripheral").LocalNet
local aNet = LocalNet.make()
```

`LocalNet.make`返回一个唯一标识着一个本地虚拟网络的整数，大部分`LocalNet`模块提供的函数都需要这样一个整数。

想要向本地网络中添加或移除一个外设，你可以这样做：

```lua
LocalNet.addPeripheral(aNet, chest)
LocalNet.removePeripheral(aNet, chest.name)
```

将一个外设添加到一个本地网络后，你就可以使用`peripheral` API 访问、包裹它。

`LocalNet`模块还提供了其它功能，你可以自行查看相关注释。

## 运行测试

本项目使用 [Busted](https://lunarmodules.github.io/busted/) 作为测试框架。确保已安装 Busted 后，在项目根目录执行：

```bash
busted
```

## 一些注意事项

确保你在`LUA_PATH`环境变量中添加了`?.lua`和`?/init.lua`模块查找路径；

## 展望

- 目前，`pullFluid`和`pullItems`等方法只能访问同一网络的限制是在函数内手动编写的，将来应该会使用其它方式限制；
- 目前，`list`等方法返回的`nbt`与 CC:Tweaked 中的返回值并不相同，我现在只是用物品序列化的`nbt`字段代替；
