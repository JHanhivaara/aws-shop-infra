create user shop_api;

grant select on products, orders to shop_api;
grant update (stock) on products to shop_api;
grant insert on orders, order_items to shop_api;
