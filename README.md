# OverCraft

## 打包与外卖提交

- `Furniture_pack`：右键或投掷存放物品，未打包时沿用桌面的合并规则，不自动打包。attack 将槽中任意普通物品（含原材料、混合物、加工中的物品）打包，包装物继续占用槽位；此后仅空手 attack 可取走，其他交互无效。空槽也可暂存已有包装物。
- `ItemPacked`：保留原始内容用于订单匹配，显示固定的 `item_packed.png`；不能解包、合并或继续加工，可以在桌面暂存、携带和投掷。
- `Furniture_drivethrough`：只接受包装物，支持手持交互、玩家碰撞交互和投掷提交；普通投掷物碰到提交点时按撞墙效果销毁，不计入提交。主机记录 `submittedCount`、`lastSubmittedItem` 并发出 `itemSubmitted` 信号，由订单管理器匹配外卖订单并结单；暂未计算奖励。
- 回归验证：使用 Godot 4.6 运行 `tests/PackedItemTest.tscn`，支持 `--headless`。

## 堂食与盘子循环

- `Furniture_dinein` 默认有 3 个干净盘（`plateCount` 可配置）；提交未包装物品消耗 1 个盘，没有盘子时拒绝提交。干净盘可通过交互或投掷补回，零盘时也可补盘。
- 未接订单系统或没有匹配订单时，提交后 5 秒将一只脏盘送到指定 `dishback`。订单系统可设置 `orderResolver(item)` 返回匹配的订单 ID，并监听 `itemSubmitted(ticketId, item, orderId)`；消费完成时调用 `completeConsumption(ticketId)`。匹配订单不使用 5 秒回盘计时，同一 ticket 只回盘一次。
- `Furniture_dishback` 不接受存入。空手 attack 或碰撞交互取走一只脏盘；盘子不能合并、打包或在普通加工设备中加工。
- `Furniture_dishwash` 右键或投掷放入一只脏盘，attack 清洗；默认 5 次（`washSteps` 可调），洗净后再空手 attack 取走。脏盘与干净盘的类型、清洗进度和家具数量均随网络状态同步。
- 三台家具均挂载 `RecipeTip`；靠近或鼠标靠近显示内容／数量，洗碗机另有进度条。盘子竖直堆叠，最多展示 6 张，浮动提示显示完整数量。
- 回归测试场景：`tests/PlateCycleTest.tscn`。

## 订单系统（测试阶段）

- 测试关卡挂载 `prefabs/OrderManager.tscn`，代码位于 `src/systems/orders/OrderManager.gd`；通过 `LevelControllerBase.INSTANCE.orderManager` 访问。
- 默认最多 5 单、每 10 秒发一单、堂食消费 8 秒。待提交和消费中的订单都占用名额；满额暂停发单，释放名额后重新等待发布间隔。降低上限不会删除已有订单，设为 0 暂停新订单。
- 默认候选列表来自配方产物；主机可调用 `setAvailableItems(Array[String])` 替换来源，空列表暂停发布。随机选择目标和堂食／外卖渠道。
- 主机 UI 调用 `setSettings(maxOrderCount, publishInterval, consumptionDuration)` 修改设置；客户端不具备修改权限。读取 `getSettings()`、`getAvailableItems()`、`getOrders()`，监听 `settingsChanged`、`ordersChanged`、`orderCompleted(order)`。返回的数据是副本，运行时请使用设置接口而非直接修改字段。
- 每单包含 `orderId/itemId/serviceType/state/createdAt/consumeUntil`；`serverTime` 和 `publishRemaining` 每秒校准一次，UI 可自行平滑倒计时，但不得自行结单。修改消费时长仅影响之后提交的订单。
- 匹配最早的同渠道待提交订单，内容必须恰好为目标物品一份；外卖必须是 `ItemPacked`。外卖立即结单；堂食进入 `consuming`，主机到时结单并回脏盘。无匹配订单仍接受物品但不计结单；堂食沿用 5 秒回盘。
- 订单与设置使用可靠完整快照同步，晚加入主动请求恢复；只有主机生成、计时、匹配与结单。回盘 ticket 和计时留在主机，客户端同步盘数、待回盘数、脏盘数及洗碗内容／进度／所需次数。家具首次状态请求改为可靠 RPC。
- 尚未实现订单 UI、奖励、失败／过期订单、主机迁移与存档。单机测试 `tests/OrderSystemTest.tscn`；双进程网络测试 `tests/OrderNetworkTest.tscn -- --host` 和 `-- --client`（端口 23459）。

## TODO

- 通用
  - UI
    - 处理器的进度条√
    - 处理器内容物分种类放大显示，(当前合成表提示?预定合成表提示？)
      - 合成表提示仅在玩家在附近/鼠标指针在附近才会提示？
      - 分为当前物品提示与预定合成表提示√
        - 当前物品提示：无有效合成表时仅显示当前每种物品数量；合成表有效时添加箭头和产物。整体动态更新√
        - 当前物品提示在玩家判定框在范围内才显示√
        - 预定合成表需等到之后的配方手册做好后再完善，留个空位即可√
        - 预定合成表全体同步。玩家鼠标没靠近时仅显示目标产物，靠近后展开（每个客户端单独处理，只同步设置好的产物），每个玩家均有编辑权限√
      - 地图放置一个CanvasLayer专门用于显示，每个机器在需要显示时进行注册与调用/更新√
    - 订单UI+对应的合成表/机器提示UI
  - 订单系统
    - 发单与提交系统/设施
      - 订单分为堂食与外卖。需要用盘子/外卖包进行打包
      - 堂食的盘子将在一定时间内返还到储物柜，需要清洗后才能再次使用
  - 配方手册
    - 根据当前订单优先提示合成树
    - 点击某个物品可设置目标产物，自动检索已有物品，玩家可手动设置每个家具位置的预定合成表（从手册里拖过去？）
    - 每个章节需要不同的配方手册，大概
  - 走steam api的联机
- 世界0  NormalHorizon
  - 机器存在随机维护问题，需要特定工具进行修复
  - 待定
