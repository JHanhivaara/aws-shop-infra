create table products (
    id          bigint generated always as identity primary key,
    name        text    not null unique,
    price_cents integer not null check (price_cents >= 0),
    stock       integer not null default 0 check (stock >= 0)
);

create table orders (
    id         bigint generated always as identity primary key,
    created_at timestamptz not null default now()
);

create table order_items (
    order_id   bigint  not null references orders(id),
    product_id bigint  not null references products(id),
    quantity   integer not null check (quantity > 0),
    primary key (product_id, order_id)
);
