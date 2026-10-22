create table event (
    id              int generated always as identity primary key,
    created_at      timestamptz     not null default now(),
    row_deleted     boolean         not null default false,
    event_name      varchar         not null,
    start_date      timestamptz     not null,
    end_date        timestamptz     not null constraint chk_event_dates check (end_date > start_date),
    auth_mode       varchar         not null constraint chk_event_auth_mode check (auth_mode in ('PHONE_OTP', 'PHONE_ONLY', 'TICKET')),
    status          varchar         not null default 'DRAFT' constraint chk_event_status check (status in ('DRAFT', 'OPEN', 'CLOSED')),
    start_elo       float8          not null,
    k_strategy      varchar         not null default 'FIXED' constraint chk_event_k_strategy check (k_strategy in ('FIXED', 'DECREASING')),
    k_params        jsonb           not null default '{}',
    live_ranking    boolean         not null default false,
    votes_per_voter smallint        not null default 20 constraint chk_event_votes_per_voter check (votes_per_voter > 0),
    ticket_regex    varchar,
    geofence_data   jsonb
);

create table car (
    id                  bigint generated always as identity primary key,
    created_at          timestamptz     not null default now(),
    row_deleted         boolean         not null default false,
    event_id            int not null constraint fk_car_event references event(id),
    car_name            varchar not null,
    description         varchar,
    number_plate        varchar, --can be null on custom projects
    country             varchar, --can be null if someone does not want to share, or it is an international entry
    entry_number        varchar not null,
    photo_reference_id  bigint,
    elo                 float8 not null,
    matches_count       int not null default 0 constraint chk_matches_count check (matches_count >= 0),
    constraint uq_car_entry_number_event_id unique (event_id, entry_number),
    constraint uq_car_event_id unique (id, event_id)
);

create index idx_car_event_elo on car (event_id, elo DESC);

create table ticket (
    id                  bigint generated always as identity primary key,
    created_at          timestamptz     not null default now(),
    row_deleted         boolean         not null default false,
    event_id            int not null constraint fk_ticket_event references event(id),
    ticket_number       varchar not null,
    constraint uq_ticket_event_id unique (event_id, ticket_number)
);

create table voter_session (
    id                  bigint generated always as identity primary key,
    created_at          timestamptz     not null default now(),
    event_id            int not null constraint fk_voter_session_event references event(id),
    identity_hash       varchar not null,
    identity_encrypted  bytea,
    status              varchar         not null default 'OPEN' constraint chk_voter_session_status check (status in ('OPEN', 'CLOSED')),
    votes_count         int not null default 0 constraint chk_votes_count check (votes_count >= 0),
    constraint uq_voter_session_identity_hash unique (event_id, identity_hash),
    constraint uq_voter_session_event_id unique (id, event_id)
);

create table matchup (
    id                  bigint generated always as identity,
    uuid                UUID  primary key default gen_random_uuid(),
    created_at          timestamptz     not null default now(),
    event_id            int not null constraint fk_matchup_event references event(id),
    voter_session_id    bigint not null,
    first_car_id        bigint not null,
    second_car_id       bigint not null,
    reversed            boolean not null default false,
    served_at           timestamptz,
    winner_car_id       bigint,
    voted_at            timestamptz,
    constraint uq_matchup_vote_cars_ids unique (voter_session_id, first_car_id, second_car_id),
    constraint fk_matchup_first_car  foreign key (first_car_id,  event_id) references car (id, event_id),
    constraint fk_matchup_second_car foreign key (second_car_id, event_id) references car (id, event_id),
    constraint chk_matchup_winner_in_pair check (winner_car_id in (first_car_id, second_car_id)),
    constraint chk_matchup_vote_consistent check ((winner_car_id is null) = (voted_at is null)),
    constraint chk_matchup_car_id_order check (first_car_id < second_car_id),
    constraint fk_matchup_voter_session foreign key (voter_session_id, event_id) references voter_session (id, event_id)
);

