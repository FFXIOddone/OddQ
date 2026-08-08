local items = {}
for _, chunk in ipairs({
  require("data/items_001"),
  require("data/items_002"),
  require("data/items_003"),
  require("data/items_004"),
  require("data/items_005"),
  require("data/items_006"),
  require("data/items_007"),
  require("data/items_008"),
  require("data/items_009"),
  require("data/items_010"),
}) do
  for _, item in ipairs(chunk) do
    items[#items + 1] = item
  end
end
return {
  schema = "oddq.items.v1",
  find_guidance = "Before farming, run /find \"<item>\" if the Find addon is installed, then check Mog House and storage containers.",
  items = items,
}
