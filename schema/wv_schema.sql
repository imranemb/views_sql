create table parties (
    id_party int,
    title_party text,
);

create table roles_quotas (
    id_party int,
    id_role int,
    min_quota int,
    max_quota int
);

create table obstacles (
    id_party int,
    id_obstacle int,
    position_col text,
    position_row text
);

create table roles (
    id_role int,
    description_role text
);

create table players (
    id_player int,
    pseudo text
);

create table players_in_parties (
    id_players_in_parties int,
    id_party int,
    id_player int,
    id_role int,
    is_alive text
);

create table turns (
    id_turn int,
    id_party int,
    start_time timestamp,
    end_time timestamp
);

create table players_play (
    id_players_in_parties int,
    id_turn int,
    start_time timestamp,
    end_time timestamp,
    action varchar(10),
    origin_position_col text,
    origin_position_row text,
    target_position_col text,
    target_position_row text
);