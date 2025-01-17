--Copyright (C) 2016 Siavoosh Payandeh Azad

library ieee;
use ieee.std_logic_1164.all;
--use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity router_credit_based_PD_C is  --fault classifier plus packet-dropping
	generic (
        DATA_WIDTH: integer := 32;
        current_address : integer := 0;
        Cx_rst : integer := 10;
        healthy_counter_threshold : integer := 8;
        faulty_counter_threshold: integer := 2;
        counter_depth: integer := 4;
        NoC_size: integer := 4
    );
    port (
    reset, clk: in std_logic;

    Rxy_reconf: in  std_logic_vector(7 downto 0);
    Reconfig : in std_logic;

    RX_N, RX_E, RX_W, RX_S, RX_L : in std_logic_vector (DATA_WIDTH-1 downto 0);
    credit_in_N, credit_in_E, credit_in_W, credit_in_S, credit_in_L: in std_logic;
    valid_in_N, valid_in_E, valid_in_W, valid_in_S, valid_in_L : in std_logic;
    valid_out_N, valid_out_E, valid_out_W, valid_out_S, valid_out_L : out std_logic;
    credit_out_N, credit_out_E, credit_out_W, credit_out_S, credit_out_L: out std_logic;
    TX_N, TX_E, TX_W, TX_S, TX_L: out std_logic_vector (DATA_WIDTH-1 downto 0);

    Faulty_N_in, Faulty_E_in, Faulty_W_in, Faulty_S_in: in std_logic;
    Faulty_N_out, Faulty_E_out, Faulty_W_out, Faulty_S_out: out std_logic

 );
end router_credit_based_PD_C;

architecture behavior of router_credit_based_PD_C is

COMPONENT FIFO_credit_based is
    generic (
              DATA_WIDTH: integer := 32
            );
    port (reset: in  std_logic;
        clk: in  std_logic;
        RX: in std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_in: in std_logic;
        read_en_N : in std_logic;
        read_en_E : in std_logic;
        read_en_W : in std_logic;
        read_en_S : in std_logic;
        read_en_L : in std_logic;

        credit_out: out std_logic;
        empty_out: out std_logic;
        Data_out: out std_logic_vector(DATA_WIDTH-1 downto 0);

        fault_info, health_info: out  std_logic;

        -- Checker outputs

        -- Functional checkers
        err_empty_full, err_empty_read_en, err_full_write_en, err_state_in_onehot, err_read_pointer_in_onehot, err_write_pointer_in_onehot,

        -- Structural checkers
        err_write_en_write_pointer, err_not_write_en_write_pointer, err_read_pointer_write_pointer_not_empty,
        err_read_pointer_write_pointer_empty, err_read_pointer_write_pointer_not_full, err_read_pointer_write_pointer_full,
        err_read_pointer_increment, err_read_pointer_not_increment, err_write_en, err_not_write_en,
        err_not_write_en1, err_not_write_en2, err_read_en_mismatch, err_read_en_mismatch1,

        -- Newly added checkers for FIFO with packet drop and fault classifier support!
        err_fake_credit_read_en_fake_credit_counter_in_increment,
        err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
        err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
        err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
        err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
        err_fake_credit_read_en_credit_out,
        err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
        err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

        -- Checkers for Packet Dropping FSM of FIFO
        err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
        err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
        err_state_out_Idle_not_fault_out_not_fake_credit,
        err_state_out_Idle_not_fault_out_not_fault_info,
        err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
        err_state_out_Idle_fault_out_fake_credit,
        err_state_out_Idle_fault_out_state_in_Packet_drop,
        err_state_out_Idle_fault_out_fault_info,
        err_state_out_Idle_fault_out_faulty_packet_in,
        err_state_out_Idle_not_health_info,
        err_state_out_Idle_not_write_fake_flit,

        err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
        err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
        err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
        err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
        err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
        err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
        err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
        err_state_out_Header_flit_valid_in_fault_out_fault_info,
        err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
        err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
        err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
        err_state_out_Header_flit_not_valid_in_not_fault_info,
        err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
        err_state_out_Header_flit_or_Body_flit_not_fake_credit,

        err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
        err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
        err_state_out_Body_flit_valid_in_not_fault_out_health_info,
        err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
        err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
        err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
        err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
        err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
        err_state_out_Body_flit_valid_in_fault_out_fault_info,
        err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
        err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
        err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
        err_state_out_Body_flit_not_valid_in_not_fault_info,
        err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
        err_state_out_Body_flit_valid_in_fault_out_not_health_info,
        err_state_out_Body_flit_valid_in_not_health_info,
        err_state_out_Body_flit_not_fake_credit,
        err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

        err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
        err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
        err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
        err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
        err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
        err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
        err_state_out_Tail_flit_valid_in_fault_out_fault_info,
        err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
        err_state_out_Tail_flit_not_valid_in_state_in_Idle,
        err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
        err_state_out_Tail_flit_not_valid_in_not_fault_info,
        err_state_out_Tail_flit_not_valid_in_not_fake_credit,
        err_state_out_Tail_flit_not_write_fake_flit,

        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
        err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
        err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
        err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
        err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
        err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
        err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
        err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
        err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
        err_state_out_Packet_drop_not_fault_info,
        err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
        err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
        err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
        err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change : out std_logic
    );
end COMPONENT;

    COMPONENT counter_threshold_classifier is
    generic (
        counter_depth: integer := 8;
        healthy_counter_threshold: integer := 4;
        faulty_counter_threshold: integer := 4
     );
    port (  reset: in  std_logic;
            clk: in  std_logic;
            faulty_packet, Healthy_packet: in  std_logic;
            Healthy, intermittent, Faulty:out std_logic
            );
    end COMPONENT;

COMPONENT allocator is
    port (  reset: in  std_logic;
            clk: in  std_logic;
            -- flow control
            credit_in_N, credit_in_E, credit_in_W, credit_in_S, credit_in_L: in std_logic;

            req_N_N, req_N_E, req_N_W, req_N_S, req_N_L: in std_logic;
            req_E_N, req_E_E, req_E_W, req_E_S, req_E_L: in std_logic;
            req_W_N, req_W_E, req_W_W, req_W_S, req_W_L: in std_logic;
            req_S_N, req_S_E, req_S_W, req_S_S, req_S_L: in std_logic;
            req_L_N, req_L_E, req_L_W, req_L_S, req_L_L: in std_logic;

            empty_N, empty_E, empty_W, empty_S, empty_L: in std_logic;
            -- grant_X_Y means the grant for X output port towards Y input port
            -- this means for any X in [N, E, W, S, L] then set grant_X_Y is one hot!
            valid_N, valid_E, valid_W, valid_S, valid_L : out std_logic;

            grant_N_N, grant_N_E, grant_N_W, grant_N_S, grant_N_L: out std_logic;
            grant_E_N, grant_E_E, grant_E_W, grant_E_S, grant_E_L: out std_logic;
            grant_W_N, grant_W_E, grant_W_W, grant_W_S, grant_W_L: out std_logic;
            grant_S_N, grant_S_E, grant_S_W, grant_S_S, grant_S_L: out std_logic;
            grant_L_N, grant_L_E, grant_L_W, grant_L_S, grant_L_L: out std_logic;

            -- Allocator logic checker outputs
            err_grant_N_N_sig_not_empty_N_grant_N_N,
            err_not_grant_N_N_sig_or_empty_N_not_grant_N_N,
            err_grant_N_E_sig_not_empty_E_grant_N_E,
            err_not_grant_N_E_sig_or_empty_E_not_grant_N_E,
            err_grant_N_W_sig_not_empty_W_grant_N_W,
            err_not_grant_N_W_sig_or_empty_W_not_grant_N_W,
            err_grant_N_S_sig_not_empty_S_grant_N_S,
            err_not_grant_N_S_sig_or_empty_S_not_grant_N_S,
            err_grant_N_L_sig_not_empty_L_grant_N_L,
            err_not_grant_N_L_sig_or_empty_L_not_grant_N_L,

            err_grant_E_N_sig_not_empty_N_grant_E_N,
            err_not_grant_E_N_sig_or_empty_N_not_grant_E_N,
            err_grant_E_E_sig_not_empty_E_grant_E_E,
            err_not_grant_E_E_sig_or_empty_E_not_grant_E_E,
            err_grant_E_W_sig_not_empty_W_grant_E_W,
            err_not_grant_E_W_sig_or_empty_W_not_grant_E_W,
            err_grant_E_S_sig_not_empty_S_grant_E_S,
            err_not_grant_E_S_sig_or_empty_S_not_grant_E_S,
            err_grant_E_L_sig_not_empty_L_grant_E_L,
            err_not_grant_E_L_sig_or_empty_L_not_grant_E_L,

            err_grant_W_N_sig_not_empty_N_grant_W_N,
            err_not_grant_W_N_sig_or_empty_N_not_grant_W_N,
            err_grant_W_E_sig_not_empty_E_grant_W_E,
            err_not_grant_W_E_sig_or_empty_E_not_grant_W_E,
            err_grant_W_W_sig_not_empty_W_grant_W_W,
            err_not_grant_W_W_sig_or_empty_W_not_grant_W_W,
            err_grant_W_S_sig_not_empty_S_grant_W_S,
            err_not_grant_W_S_sig_or_empty_S_not_grant_W_S,
            err_grant_W_L_sig_not_empty_L_grant_W_L,
            err_not_grant_W_L_sig_or_empty_L_not_grant_W_L,

            err_grant_S_N_sig_not_empty_N_grant_S_N,
            err_not_grant_S_N_sig_or_empty_N_not_grant_S_N,
            err_grant_S_E_sig_not_empty_E_grant_S_E,
            err_not_grant_S_E_sig_or_empty_E_not_grant_S_E,
            err_grant_S_W_sig_not_empty_W_grant_S_W,
            err_not_grant_S_W_sig_or_empty_W_not_grant_S_W,
            err_grant_S_S_sig_not_empty_S_grant_S_S,
            err_not_grant_S_S_sig_or_empty_S_not_grant_S_S,
            err_grant_S_L_sig_not_empty_L_grant_S_L,
            err_not_grant_S_L_sig_or_empty_L_not_grant_S_L,

            err_grant_L_N_sig_not_empty_N_grant_L_N,
            err_not_grant_L_N_sig_or_empty_N_not_grant_L_N,
            err_grant_L_E_sig_not_empty_E_grant_L_E,
            err_not_grant_L_E_sig_or_empty_E_not_grant_L_E,
            err_grant_L_W_sig_not_empty_W_grant_L_W,
            err_not_grant_L_W_sig_or_empty_W_not_grant_L_W,
            err_grant_L_S_sig_not_empty_S_grant_L_S,
            err_not_grant_L_S_sig_or_empty_S_not_grant_L_S,
            err_grant_L_L_sig_not_empty_L_grant_L_L,
            err_not_grant_L_L_sig_or_empty_L_not_grant_L_L,

            err_grant_signals_not_empty_grant_N,
            err_not_grant_signals_empty_not_grant_N,
            err_grant_signals_not_empty_grant_E,
            err_not_grant_signals_empty_not_grant_E,
            err_grant_signals_not_empty_grant_W,
            err_not_grant_signals_empty_not_grant_W,
            err_grant_signals_not_empty_grant_S,
            err_not_grant_signals_empty_not_grant_S,
            err_grant_signals_not_empty_grant_L,
            err_not_grant_signals_empty_not_grant_L,

            err_grants_valid_not_match,

            -- Allocator credit counter logic checker outputs
            err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal,
            err_credit_in_N_credit_counter_N_out_increment,
            err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change,
            err_grant_N_credit_counter_N_out_decrement,
            err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change,
            err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal,

            err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal,
            err_credit_in_E_credit_counter_E_out_increment,
            err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change,
            err_grant_E_credit_counter_E_out_decrement,
            err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change,
            err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal,

            err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal,
            err_credit_in_W_credit_counter_W_out_increment,
            err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change,
            err_grant_W_credit_counter_W_out_decrement,
            err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change,
            err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal,

            err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal,
            err_credit_in_S_credit_counter_S_out_increment,
            err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change,
            err_grant_S_credit_counter_S_out_decrement,
            err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change,
            err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal,

            err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal,
            err_credit_in_L_credit_counter_L_out_increment,
            err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change,
            err_grant_L_credit_counter_L_out_decrement,
            err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change,
            err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal,

            -- Arbiter_in checker outputs

            -- North Arbiter_in checker outputs
            N_err_Requests_state_in_state_not_equal,

            N_err_IDLE_Req_N, N_err_IDLE_grant_N,N_err_North_Req_N, N_err_North_grant_N, N_err_East_Req_E, N_err_East_grant_E,
            N_err_West_Req_W, N_err_West_grant_W, N_err_South_Req_S,N_err_South_grant_S,N_err_Local_Req_L, N_err_Local_grant_L,

            N_err_IDLE_Req_E, N_err_IDLE_grant_E, N_err_North_Req_E, N_err_North_grant_E, N_err_East_Req_W, N_err_East_grant_W,
            N_err_West_Req_S, N_err_West_grant_S, N_err_South_Req_L, N_err_South_grant_L, N_err_Local_Req_N, N_err_Local_grant_N,

            N_err_IDLE_Req_W, N_err_IDLE_grant_W, N_err_North_Req_W, N_err_North_grant_W, N_err_East_Req_S, N_err_East_grant_S,
            N_err_West_Req_L, N_err_West_grant_L, N_err_South_Req_N,  N_err_South_grant_N, N_err_Local_Req_E, N_err_Local_grant_E,

            N_err_IDLE_Req_S, N_err_IDLE_grant_S, N_err_North_Req_S, N_err_North_grant_S, N_err_East_Req_L, N_err_East_grant_L,
            N_err_West_Req_N, N_err_West_grant_N, N_err_South_Req_E, N_err_South_grant_E, N_err_Local_Req_W, N_err_Local_grant_W,

            N_err_IDLE_Req_L, N_err_IDLE_grant_L, N_err_North_Req_L, N_err_North_grant_L, N_err_East_Req_N, N_err_East_grant_N,
            N_err_West_Req_E, N_err_West_grant_E, N_err_South_Req_W, N_err_South_grant_W, N_err_Local_Req_S, N_err_Local_grant_S,

            N_err_state_in_onehot, N_err_no_request_grants, N_err_request_no_grants,

            N_err_no_Req_N_grant_N, N_err_no_Req_E_grant_E,  N_err_no_Req_W_grant_W,  N_err_no_Req_S_grant_S, N_err_no_Req_L_grant_L,

            -- East Arbiter_in checker outputs
            E_err_Requests_state_in_state_not_equal,

            E_err_IDLE_Req_N, E_err_IDLE_grant_N,E_err_North_Req_N, E_err_North_grant_N, E_err_East_Req_E, E_err_East_grant_E,
            E_err_West_Req_W, E_err_West_grant_W, E_err_South_Req_S,E_err_South_grant_S,E_err_Local_Req_L, E_err_Local_grant_L,

            E_err_IDLE_Req_E, E_err_IDLE_grant_E, E_err_North_Req_E, E_err_North_grant_E, E_err_East_Req_W, E_err_East_grant_W,
            E_err_West_Req_S, E_err_West_grant_S, E_err_South_Req_L, E_err_South_grant_L, E_err_Local_Req_N, E_err_Local_grant_N,

            E_err_IDLE_Req_W, E_err_IDLE_grant_W, E_err_North_Req_W, E_err_North_grant_W, E_err_East_Req_S, E_err_East_grant_S,
            E_err_West_Req_L, E_err_West_grant_L, E_err_South_Req_N,  E_err_South_grant_N, E_err_Local_Req_E, E_err_Local_grant_E,

            E_err_IDLE_Req_S, E_err_IDLE_grant_S, E_err_North_Req_S, E_err_North_grant_S, E_err_East_Req_L, E_err_East_grant_L,
            E_err_West_Req_N, E_err_West_grant_N, E_err_South_Req_E, E_err_South_grant_E, E_err_Local_Req_W, E_err_Local_grant_W,

            E_err_IDLE_Req_L, E_err_IDLE_grant_L, E_err_North_Req_L, E_err_North_grant_L, E_err_East_Req_N, E_err_East_grant_N,
            E_err_West_Req_E, E_err_West_grant_E, E_err_South_Req_W, E_err_South_grant_W, E_err_Local_Req_S, E_err_Local_grant_S,

            E_err_state_in_onehot, E_err_no_request_grants, E_err_request_no_grants,

            E_err_no_Req_N_grant_N, E_err_no_Req_E_grant_E, E_err_no_Req_W_grant_W, E_err_no_Req_S_grant_S, E_err_no_Req_L_grant_L,

            -- West Arbiter_in checker outputs
            W_err_Requests_state_in_state_not_equal,

            W_err_IDLE_Req_N, W_err_IDLE_grant_N,W_err_North_Req_N, W_err_North_grant_N, W_err_East_Req_E, W_err_East_grant_E,
            W_err_West_Req_W, W_err_West_grant_W, W_err_South_Req_S,W_err_South_grant_S,W_err_Local_Req_L, W_err_Local_grant_L,

            W_err_IDLE_Req_E, W_err_IDLE_grant_E, W_err_North_Req_E, W_err_North_grant_E, W_err_East_Req_W, W_err_East_grant_W,
            W_err_West_Req_S, W_err_West_grant_S, W_err_South_Req_L, W_err_South_grant_L, W_err_Local_Req_N, W_err_Local_grant_N,

            W_err_IDLE_Req_W, W_err_IDLE_grant_W, W_err_North_Req_W, W_err_North_grant_W, W_err_East_Req_S, W_err_East_grant_S,
            W_err_West_Req_L, W_err_West_grant_L, W_err_South_Req_N,  W_err_South_grant_N, W_err_Local_Req_E, W_err_Local_grant_E,

            W_err_IDLE_Req_S, W_err_IDLE_grant_S, W_err_North_Req_S, W_err_North_grant_S, W_err_East_Req_L, W_err_East_grant_L,
            W_err_West_Req_N, W_err_West_grant_N, W_err_South_Req_E, W_err_South_grant_E, W_err_Local_Req_W, W_err_Local_grant_W,

            W_err_IDLE_Req_L, W_err_IDLE_grant_L, W_err_North_Req_L, W_err_North_grant_L, W_err_East_Req_N, W_err_East_grant_N,
            W_err_West_Req_E, W_err_West_grant_E, W_err_South_Req_W, W_err_South_grant_W, W_err_Local_Req_S, W_err_Local_grant_S,

            W_err_state_in_onehot, W_err_no_request_grants, W_err_request_no_grants,

            W_err_no_Req_N_grant_N, W_err_no_Req_E_grant_E,  W_err_no_Req_W_grant_W,  W_err_no_Req_S_grant_S,  W_err_no_Req_L_grant_L,

            -- South Arbiter_in checker outputs
            S_err_Requests_state_in_state_not_equal,

            S_err_IDLE_Req_N, S_err_IDLE_grant_N,S_err_North_Req_N, S_err_North_grant_N, S_err_East_Req_E, S_err_East_grant_E,
            S_err_West_Req_W, S_err_West_grant_W, S_err_South_Req_S,S_err_South_grant_S,S_err_Local_Req_L, S_err_Local_grant_L,

            S_err_IDLE_Req_E, S_err_IDLE_grant_E, S_err_North_Req_E, S_err_North_grant_E, S_err_East_Req_W, S_err_East_grant_W,
            S_err_West_Req_S, S_err_West_grant_S, S_err_South_Req_L, S_err_South_grant_L, S_err_Local_Req_N, S_err_Local_grant_N,

            S_err_IDLE_Req_W, S_err_IDLE_grant_W, S_err_North_Req_W, S_err_North_grant_W, S_err_East_Req_S, S_err_East_grant_S,
            S_err_West_Req_L, S_err_West_grant_L, S_err_South_Req_N,  S_err_South_grant_N, S_err_Local_Req_E, S_err_Local_grant_E,

            S_err_IDLE_Req_S, S_err_IDLE_grant_S, S_err_North_Req_S, S_err_North_grant_S, S_err_East_Req_L, S_err_East_grant_L,
            S_err_West_Req_N, S_err_West_grant_N, S_err_South_Req_E, S_err_South_grant_E, S_err_Local_Req_W, S_err_Local_grant_W,

            S_err_IDLE_Req_L, S_err_IDLE_grant_L, S_err_North_Req_L, S_err_North_grant_L, S_err_East_Req_N, S_err_East_grant_N,
            S_err_West_Req_E, S_err_West_grant_E, S_err_South_Req_W, S_err_South_grant_W, S_err_Local_Req_S, S_err_Local_grant_S,

            S_err_state_in_onehot, S_err_no_request_grants, S_err_request_no_grants,

            S_err_no_Req_N_grant_N, S_err_no_Req_E_grant_E,  S_err_no_Req_W_grant_W,  S_err_no_Req_S_grant_S, S_err_no_Req_L_grant_L,

            -- Local Arbiter_in checker outputs
            L_err_Requests_state_in_state_not_equal,

            L_err_IDLE_Req_N, L_err_IDLE_grant_N,L_err_North_Req_N, L_err_North_grant_N, L_err_East_Req_E, L_err_East_grant_E,
            L_err_West_Req_W, L_err_West_grant_W, L_err_South_Req_S,L_err_South_grant_S,L_err_Local_Req_L, L_err_Local_grant_L,

            L_err_IDLE_Req_E, L_err_IDLE_grant_E, L_err_North_Req_E, L_err_North_grant_E, L_err_East_Req_W, L_err_East_grant_W,
            L_err_West_Req_S, L_err_West_grant_S, L_err_South_Req_L, L_err_South_grant_L, L_err_Local_Req_N, L_err_Local_grant_N,

            L_err_IDLE_Req_W, L_err_IDLE_grant_W, L_err_North_Req_W, L_err_North_grant_W, L_err_East_Req_S, L_err_East_grant_S,
            L_err_West_Req_L, L_err_West_grant_L, L_err_South_Req_N,  L_err_South_grant_N, L_err_Local_Req_E, L_err_Local_grant_E,

            L_err_IDLE_Req_S, L_err_IDLE_grant_S, L_err_North_Req_S, L_err_North_grant_S, L_err_East_Req_L, L_err_East_grant_L,
            L_err_West_Req_N, L_err_West_grant_N, L_err_South_Req_E, L_err_South_grant_E, L_err_Local_Req_W, L_err_Local_grant_W,

            L_err_IDLE_Req_L, L_err_IDLE_grant_L, L_err_North_Req_L, L_err_North_grant_L, L_err_East_Req_N, L_err_East_grant_N,
            L_err_West_Req_E, L_err_West_grant_E, L_err_South_Req_W, L_err_South_grant_W, L_err_Local_Req_S, L_err_Local_grant_S,

            L_err_state_in_onehot, L_err_no_request_grants, L_err_request_no_grants,

            L_err_no_Req_N_grant_N, L_err_no_Req_E_grant_E,  L_err_no_Req_W_grant_W, L_err_no_Req_S_grant_S, L_err_no_Req_L_grant_L,

            -- Arbiter_out checker outputs

            -- North Arbiter_out checker outputs
            N_arbiter_out_err_Requests_state_in_state_not_equal,

            N_err_IDLE_req_X_N,
            N_err_North_req_X_N,
            N_err_North_credit_not_zero_req_X_N_grant_N,
            N_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            N_err_East_req_X_E,
            N_err_East_credit_not_zero_req_X_E_grant_E,
            N_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            N_err_West_req_X_W,
            N_err_West_credit_not_zero_req_X_W_grant_W,
            N_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            N_err_South_req_X_S,
            N_err_South_credit_not_zero_req_X_S_grant_S,
            N_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            N_err_Local_req_X_L,
            N_err_Local_credit_not_zero_req_X_L_grant_L,
            N_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            N_err_IDLE_req_X_E, N_err_North_req_X_E, N_err_East_req_X_W, N_err_West_req_X_S, N_err_South_req_X_L, N_err_Local_req_X_N,
            N_err_IDLE_req_X_W, N_err_North_req_X_W, N_err_East_req_X_S, N_err_West_req_X_L, N_err_South_req_X_N, N_err_Local_req_X_E,
            N_err_IDLE_req_X_S, N_err_North_req_X_S, N_err_East_req_X_L, N_err_West_req_X_N, N_err_South_req_X_E, N_err_Local_req_X_W,
            N_err_IDLE_req_X_L, N_err_North_req_X_L, N_err_East_req_X_N, N_err_West_req_X_E, N_err_South_req_X_W, N_err_Local_req_X_S,

            N_arbiter_out_err_state_in_onehot,
            N_arbiter_out_err_no_request_grants,
            N_err_request_IDLE_state,

            N_err_request_IDLE_not_Grants, N_err_state_North_Invalid_Grant,N_err_state_East_Invalid_Grant,
            N_err_state_West_Invalid_Grant, N_err_state_South_Invalid_Grant,N_err_state_Local_Invalid_Grant,
            N_err_Grants_onehot_or_all_zero,

            -- East Arbiter_out checker outputs
            E_arbiter_out_err_Requests_state_in_state_not_equal,

            E_err_IDLE_req_X_N,
            E_err_North_req_X_N,
            E_err_North_credit_not_zero_req_X_N_grant_N,
            E_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            E_err_East_req_X_E,
            E_err_East_credit_not_zero_req_X_E_grant_E,
            E_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            E_err_West_req_X_W,
            E_err_West_credit_not_zero_req_X_W_grant_W,
            E_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            E_err_South_req_X_S,
            E_err_South_credit_not_zero_req_X_S_grant_S,
            E_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            E_err_Local_req_X_L,
            E_err_Local_credit_not_zero_req_X_L_grant_L,
            E_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            E_err_IDLE_req_X_E, E_err_North_req_X_E, E_err_East_req_X_W, E_err_West_req_X_S, E_err_South_req_X_L, E_err_Local_req_X_N,
            E_err_IDLE_req_X_W, E_err_North_req_X_W, E_err_East_req_X_S, E_err_West_req_X_L, E_err_South_req_X_N, E_err_Local_req_X_E,
            E_err_IDLE_req_X_S, E_err_North_req_X_S, E_err_East_req_X_L, E_err_West_req_X_N, E_err_South_req_X_E, E_err_Local_req_X_W,
            E_err_IDLE_req_X_L, E_err_North_req_X_L, E_err_East_req_X_N, E_err_West_req_X_E, E_err_South_req_X_W, E_err_Local_req_X_S,

            E_arbiter_out_err_state_in_onehot, E_arbiter_out_err_no_request_grants, E_err_request_IDLE_state,

            E_err_request_IDLE_not_Grants, E_err_state_North_Invalid_Grant, E_err_state_East_Invalid_Grant,
            E_err_state_West_Invalid_Grant, E_err_state_South_Invalid_Grant, E_err_state_Local_Invalid_Grant,
            E_err_Grants_onehot_or_all_zero,

            -- West Arbiter_out checker outputs
            W_arbiter_out_err_Requests_state_in_state_not_equal,

            W_err_IDLE_req_X_N,
            W_err_North_req_X_N,
            W_err_North_credit_not_zero_req_X_N_grant_N,
            W_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            W_err_East_req_X_E,
            W_err_East_credit_not_zero_req_X_E_grant_E,
            W_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            W_err_West_req_X_W,
            W_err_West_credit_not_zero_req_X_W_grant_W,
            W_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            W_err_South_req_X_S,
            W_err_South_credit_not_zero_req_X_S_grant_S,
            W_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            W_err_Local_req_X_L,
            W_err_Local_credit_not_zero_req_X_L_grant_L,
            W_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            W_err_IDLE_req_X_E, W_err_North_req_X_E, W_err_East_req_X_W, W_err_West_req_X_S, W_err_South_req_X_L, W_err_Local_req_X_N,
            W_err_IDLE_req_X_W, W_err_North_req_X_W, W_err_East_req_X_S, W_err_West_req_X_L, W_err_South_req_X_N, W_err_Local_req_X_E,
            W_err_IDLE_req_X_S, W_err_North_req_X_S, W_err_East_req_X_L, W_err_West_req_X_N, W_err_South_req_X_E, W_err_Local_req_X_W,
            W_err_IDLE_req_X_L, W_err_North_req_X_L, W_err_East_req_X_N, W_err_West_req_X_E, W_err_South_req_X_W, W_err_Local_req_X_S,

            W_arbiter_out_err_state_in_onehot, W_arbiter_out_err_no_request_grants, W_err_request_IDLE_state,

            W_err_request_IDLE_not_Grants, W_err_state_North_Invalid_Grant,W_err_state_East_Invalid_Grant, W_err_state_West_Invalid_Grant,
            W_err_state_South_Invalid_Grant,W_err_state_Local_Invalid_Grant,W_err_Grants_onehot_or_all_zero,

            -- South Arbiter_out checker outputs
            S_arbiter_out_err_Requests_state_in_state_not_equal,

            S_err_IDLE_req_X_N,
            S_err_North_req_X_N,
            S_err_North_credit_not_zero_req_X_N_grant_N,
            S_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            S_err_East_req_X_E,
            S_err_East_credit_not_zero_req_X_E_grant_E,
            S_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            S_err_West_req_X_W,
            S_err_West_credit_not_zero_req_X_W_grant_W,
            S_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            S_err_South_req_X_S,
            S_err_South_credit_not_zero_req_X_S_grant_S,
            S_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            S_err_Local_req_X_L,
            S_err_Local_credit_not_zero_req_X_L_grant_L,
            S_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            S_err_IDLE_req_X_E, S_err_North_req_X_E, S_err_East_req_X_W, S_err_West_req_X_S, S_err_South_req_X_L, S_err_Local_req_X_N,
            S_err_IDLE_req_X_W, S_err_North_req_X_W, S_err_East_req_X_S, S_err_West_req_X_L, S_err_South_req_X_N, S_err_Local_req_X_E,
            S_err_IDLE_req_X_S, S_err_North_req_X_S, S_err_East_req_X_L, S_err_West_req_X_N, S_err_South_req_X_E, S_err_Local_req_X_W,
            S_err_IDLE_req_X_L, S_err_North_req_X_L, S_err_East_req_X_N, S_err_West_req_X_E, S_err_South_req_X_W, S_err_Local_req_X_S,

            S_arbiter_out_err_state_in_onehot, S_arbiter_out_err_no_request_grants, S_err_request_IDLE_state,

            S_err_request_IDLE_not_Grants, S_err_state_North_Invalid_Grant,S_err_state_East_Invalid_Grant,
            S_err_state_West_Invalid_Grant, S_err_state_South_Invalid_Grant,S_err_state_Local_Invalid_Grant,
            S_err_Grants_onehot_or_all_zero,

            -- Local Arbiter_out checker outputs
            L_arbiter_out_err_Requests_state_in_state_not_equal,

            L_err_IDLE_req_X_N,
            L_err_North_req_X_N,
            L_err_North_credit_not_zero_req_X_N_grant_N,
            L_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            L_err_East_req_X_E,
            L_err_East_credit_not_zero_req_X_E_grant_E,
            L_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            L_err_West_req_X_W,
            L_err_West_credit_not_zero_req_X_W_grant_W,
            L_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            L_err_South_req_X_S,
            L_err_South_credit_not_zero_req_X_S_grant_S,
            L_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            L_err_Local_req_X_L,
            L_err_Local_credit_not_zero_req_X_L_grant_L,
            L_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            L_err_IDLE_req_X_E, L_err_North_req_X_E, L_err_East_req_X_W, L_err_West_req_X_S, L_err_South_req_X_L, L_err_Local_req_X_N,
            L_err_IDLE_req_X_W, L_err_North_req_X_W, L_err_East_req_X_S, L_err_West_req_X_L, L_err_South_req_X_N, L_err_Local_req_X_E,
            L_err_IDLE_req_X_S, L_err_North_req_X_S, L_err_East_req_X_L, L_err_West_req_X_N, L_err_South_req_X_E, L_err_Local_req_X_W,
            L_err_IDLE_req_X_L, L_err_North_req_X_L, L_err_East_req_X_N, L_err_West_req_X_E, L_err_South_req_X_W, L_err_Local_req_X_S,

            L_arbiter_out_err_state_in_onehot, L_arbiter_out_err_no_request_grants, L_err_request_IDLE_state,

            L_err_request_IDLE_not_Grants,
            L_err_state_North_Invalid_Grant,
            L_err_state_East_Invalid_Grant,
            L_err_state_West_Invalid_Grant,
            L_err_state_South_Invalid_Grant,
            L_err_state_Local_Invalid_Grant,
            L_err_Grants_onehot_or_all_zero : out std_logic
            );
end COMPONENT;

COMPONENT LBDR_packet_drop is
    generic (
        cur_addr_rst: integer := 8;

        Cx_rst: integer := 8;
        NoC_size: integer := 4
    );
    port (  reset: in  std_logic;
            clk: in  std_logic;

            Rxy_reconf: in  std_logic_vector(7 downto 0);
            Reconfig : in std_logic;

            Faulty_C_N, Faulty_C_E, Faulty_C_W, Faulty_C_S: in std_logic;

            empty: in  std_logic;
            flit_type: in std_logic_vector(2 downto 0);
            dst_addr: in std_logic_vector(NoC_size-1 downto 0);
            packet_drop_order: out std_logic;
              grant_N, grant_E, grant_W, grant_S, grant_L: in std_logic;
            Req_N, Req_E, Req_W, Req_S, Req_L:out std_logic;

            -- Checker outputs
            -- Routing part checkers
            err_header_empty_Requests_FF_Requests_in,
            err_tail_Requests_in_all_zero,
            err_tail_empty_Requests_FF_Requests_in,
            err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            err_grants_onehot,
            err_grants_mismatch,
            err_header_tail_Requests_FF_Requests_in,
            err_dst_addr_cur_addr_N1,
            err_dst_addr_cur_addr_not_N1,
            err_dst_addr_cur_addr_E1,
            err_dst_addr_cur_addr_not_E1,
            err_dst_addr_cur_addr_W1,
            err_dst_addr_cur_addr_not_W1,
            err_dst_addr_cur_addr_S1,
            err_dst_addr_cur_addr_not_S1,
            err_dst_addr_cur_addr_not_Req_L_in,
            err_dst_addr_cur_addr_Req_L_in,
            err_header_not_empty_Req_N_in,
            err_header_not_empty_Req_E_in,
            err_header_not_empty_Req_W_in,
            err_header_not_empty_Req_S_in,
            err_header_not_empty_packet_drop_in,
            err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            err_header_empty_packet_drop_in_packet_drop_equal,
            err_tail_not_empty_packet_drop_not_packet_drop_in,
            err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            err_packet_drop_order,

            -- Cx_Reconf checkers
            err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            -- Rxy_Reconf checkers
            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal : out std_logic
            );
end COMPONENT;

 	COMPONENT XBAR is
    generic (
        DATA_WIDTH: integer := 32
    );
    port (
        North_in: in std_logic_vector(DATA_WIDTH-1 downto 0);
        East_in: in std_logic_vector(DATA_WIDTH-1 downto 0);
        West_in: in std_logic_vector(DATA_WIDTH-1 downto 0);
        South_in: in std_logic_vector(DATA_WIDTH-1 downto 0);
        Local_in: in std_logic_vector(DATA_WIDTH-1 downto 0);
        sel: in std_logic_vector (4 downto 0);
        Data_out: out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
	end COMPONENT;

  	signal FIFO_D_out_N, FIFO_D_out_E, FIFO_D_out_W, FIFO_D_out_S, FIFO_D_out_L: std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Grant_XY : Grant signal generated from Arbiter for output X connected to FIFO of input Y

 	signal Grant_NN, Grant_NE, Grant_NW, Grant_NS, Grant_NL: std_logic;
 	signal Grant_EN, Grant_EE, Grant_EW, Grant_ES, Grant_EL: std_logic;
 	signal Grant_WN, Grant_WE, Grant_WW, Grant_WS, Grant_WL: std_logic;
 	signal Grant_SN, Grant_SE, Grant_SW, Grant_SS, Grant_SL: std_logic;
 	signal Grant_LN, Grant_LE, Grant_LW, Grant_LS, Grant_LL: std_logic;

 	signal Req_NN, Req_EN, Req_WN, Req_SN, Req_LN: std_logic;
 	signal Req_NE, Req_EE, Req_WE, Req_SE, Req_LE: std_logic;
 	signal Req_NW, Req_EW, Req_WW, Req_SW, Req_LW: std_logic;
 	signal Req_NS, Req_ES, Req_WS, Req_SS, Req_LS: std_logic;
 	signal Req_NL, Req_EL, Req_WL, Req_SL, Req_LL: std_logic;

    signal empty_N, empty_E, empty_W, empty_S, empty_L: std_logic;


    signal Xbar_sel: array (4 downto 0) of std_logic_vector(4 downto 0);

 	signal Xbar_sel_N, Xbar_sel_E, Xbar_sel_W, Xbar_sel_S, Xbar_sel_L: std_logic_vector(4 downto 0);

    signal faulty_packet_N, faulty_packet_E, faulty_packet_W, faulty_packet_S, faulty_packet_L:  std_logic;
    signal healthy_packet_N, healthy_packet_E, healthy_packet_W, healthy_packet_S, healthy_packet_L:  std_logic;

    signal packet_drop_order_N, packet_drop_order_E, packet_drop_order_W, packet_drop_order_S, packet_drop_order_L:  std_logic;

    signal healthy_link_N, healthy_link_E, healthy_link_W, healthy_link_S, healthy_link_L:  std_logic;
    signal sig_Faulty_N_out, sig_Faulty_E_out, sig_Faulty_W_out, sig_Faulty_S_out, faulty_link_L:  std_logic;
    signal intermittent_link_N, intermittent_link_E, intermittent_link_W, intermittent_link_S, intermittent_link_L:  std_logic;

    -- Signals needed for control part checkers

    -- Signals needed for LBDR packet drop checkers
    -- North
    signal  N_err_header_empty_Requests_FF_Requests_in,
            N_err_tail_Requests_in_all_zero,
            N_err_tail_empty_Requests_FF_Requests_in,
            N_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            N_err_grants_onehot,
            N_err_grants_mismatch,
            N_err_header_tail_Requests_FF_Requests_in,
            N_err_dst_addr_cur_addr_N1,
            N_err_dst_addr_cur_addr_not_N1,
            N_err_dst_addr_cur_addr_E1,
            N_err_dst_addr_cur_addr_not_E1,
            N_err_dst_addr_cur_addr_W1,
            N_err_dst_addr_cur_addr_not_W1,
            N_err_dst_addr_cur_addr_S1,
            N_err_dst_addr_cur_addr_not_S1,
            N_err_dst_addr_cur_addr_not_Req_L_in,
            N_err_dst_addr_cur_addr_Req_L_in,
            N_err_header_not_empty_Req_N_in,
            N_err_header_not_empty_Req_E_in,
            N_err_header_not_empty_Req_W_in,
            N_err_header_not_empty_Req_S_in,
            N_err_header_not_empty_packet_drop_in,
            N_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            N_err_header_empty_packet_drop_in_packet_drop_equal,
            N_err_tail_not_empty_packet_drop_not_packet_drop_in,
            N_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            N_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            N_err_packet_drop_order,

            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal: std_logic;

    -- East
    signal  E_err_header_empty_Requests_FF_Requests_in,
            E_err_tail_Requests_in_all_zero,
            E_err_tail_empty_Requests_FF_Requests_in,
            E_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            E_err_grants_onehot,
            E_err_grants_mismatch,
            E_err_header_tail_Requests_FF_Requests_in,
            E_err_dst_addr_cur_addr_N1,
            E_err_dst_addr_cur_addr_not_N1,
            E_err_dst_addr_cur_addr_E1,
            E_err_dst_addr_cur_addr_not_E1,
            E_err_dst_addr_cur_addr_W1,
            E_err_dst_addr_cur_addr_not_W1,
            E_err_dst_addr_cur_addr_S1,
            E_err_dst_addr_cur_addr_not_S1,
            E_err_dst_addr_cur_addr_not_Req_L_in,
            E_err_dst_addr_cur_addr_Req_L_in,
            E_err_header_not_empty_Req_N_in,
            E_err_header_not_empty_Req_E_in,
            E_err_header_not_empty_Req_W_in,
            E_err_header_not_empty_Req_S_in,
            E_err_header_not_empty_packet_drop_in,
            E_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            E_err_header_empty_packet_drop_in_packet_drop_equal,
            E_err_tail_not_empty_packet_drop_not_packet_drop_in,
            E_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            E_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            E_err_packet_drop_order,

            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal: std_logic;

    -- West
    signal  W_err_header_empty_Requests_FF_Requests_in,
            W_err_tail_Requests_in_all_zero,
            W_err_tail_empty_Requests_FF_Requests_in,
            W_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            W_err_grants_onehot,
            W_err_grants_mismatch,
            W_err_header_tail_Requests_FF_Requests_in,
            W_err_dst_addr_cur_addr_N1,
            W_err_dst_addr_cur_addr_not_N1,
            W_err_dst_addr_cur_addr_E1,
            W_err_dst_addr_cur_addr_not_E1,
            W_err_dst_addr_cur_addr_W1,
            W_err_dst_addr_cur_addr_not_W1,
            W_err_dst_addr_cur_addr_S1,
            W_err_dst_addr_cur_addr_not_S1,
            W_err_dst_addr_cur_addr_not_Req_L_in,
            W_err_dst_addr_cur_addr_Req_L_in,
            W_err_header_not_empty_Req_N_in,
            W_err_header_not_empty_Req_E_in,
            W_err_header_not_empty_Req_W_in,
            W_err_header_not_empty_Req_S_in,
            W_err_header_not_empty_packet_drop_in,
            W_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            W_err_header_empty_packet_drop_in_packet_drop_equal,
            W_err_tail_not_empty_packet_drop_not_packet_drop_in,
            W_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            W_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            W_err_packet_drop_order,

            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal: std_logic;

    -- South
    signal  S_err_header_empty_Requests_FF_Requests_in,
            S_err_tail_Requests_in_all_zero,
            S_err_tail_empty_Requests_FF_Requests_in,
            S_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            S_err_grants_onehot,
            S_err_grants_mismatch,
            S_err_header_tail_Requests_FF_Requests_in,
            S_err_dst_addr_cur_addr_N1,
            S_err_dst_addr_cur_addr_not_N1,
            S_err_dst_addr_cur_addr_E1,
            S_err_dst_addr_cur_addr_not_E1,
            S_err_dst_addr_cur_addr_W1,
            S_err_dst_addr_cur_addr_not_W1,
            S_err_dst_addr_cur_addr_S1,
            S_err_dst_addr_cur_addr_not_S1,
            S_err_dst_addr_cur_addr_not_Req_L_in,
            S_err_dst_addr_cur_addr_Req_L_in,
            S_err_header_not_empty_Req_N_in,
            S_err_header_not_empty_Req_E_in,
            S_err_header_not_empty_Req_W_in,
            S_err_header_not_empty_Req_S_in,
            S_err_header_not_empty_packet_drop_in,
            S_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            S_err_header_empty_packet_drop_in_packet_drop_equal,
            S_err_tail_not_empty_packet_drop_not_packet_drop_in,
            S_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            S_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            S_err_packet_drop_order,

            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal: std_logic;

    -- Local
    signal  L_err_header_empty_Requests_FF_Requests_in,
            L_err_tail_Requests_in_all_zero,
            L_err_tail_empty_Requests_FF_Requests_in,
            L_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            L_err_grants_onehot,
            L_err_grants_mismatch,
            L_err_header_tail_Requests_FF_Requests_in,
            L_err_dst_addr_cur_addr_N1,
            L_err_dst_addr_cur_addr_not_N1,
            L_err_dst_addr_cur_addr_E1,
            L_err_dst_addr_cur_addr_not_E1,
            L_err_dst_addr_cur_addr_W1,
            L_err_dst_addr_cur_addr_not_W1,
            L_err_dst_addr_cur_addr_S1,
            L_err_dst_addr_cur_addr_not_S1,
            L_err_dst_addr_cur_addr_not_Req_L_in,
            L_err_dst_addr_cur_addr_Req_L_in,
            L_err_header_not_empty_Req_N_in,
            L_err_header_not_empty_Req_E_in,
            L_err_header_not_empty_Req_W_in,
            L_err_header_not_empty_Req_S_in,
            L_err_header_not_empty_packet_drop_in,
            L_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            L_err_header_empty_packet_drop_in_packet_drop_equal,
            L_err_tail_not_empty_packet_drop_not_packet_drop_in,
            L_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            L_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            L_err_packet_drop_order,

            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal: std_logic;

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

    -- Signals needed for FIFO packet drop with fault classifier support checkers

            -- North
            -- Functional checkers
   signal   N_err_empty_full,
            N_err_empty_read_en,
            N_err_full_write_en,
            N_err_state_in_onehot,
            N_err_read_pointer_in_onehot,
            N_err_write_pointer_in_onehot,

            -- Structural checkers
            N_err_write_en_write_pointer,
            N_err_not_write_en_write_pointer,
            N_err_read_pointer_write_pointer_not_empty,
            N_err_read_pointer_write_pointer_empty,
            N_err_read_pointer_write_pointer_not_full,
            N_err_read_pointer_write_pointer_full,
            N_err_read_pointer_increment,
            N_err_read_pointer_not_increment,
            N_err_write_en,
            N_err_not_write_en,
            N_err_not_write_en1,
            N_err_not_write_en2,
            N_err_read_en_mismatch,
            N_err_read_en_mismatch1,

            -- Newly added checkers for FIFO with packet drop and fault classifier support!
            N_err_fake_credit_read_en_fake_credit_counter_in_increment,
            N_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
            N_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
            N_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
            N_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
            N_err_fake_credit_read_en_credit_out,
            N_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
            N_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

            -- Checkers for Packet Dropping FSM of FIFO
            N_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
            N_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
            N_err_state_out_Idle_not_fault_out_not_fake_credit,
            N_err_state_out_Idle_not_fault_out_not_fault_info,
            N_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
            N_err_state_out_Idle_fault_out_fake_credit,
            N_err_state_out_Idle_fault_out_state_in_Packet_drop,
            N_err_state_out_Idle_fault_out_fault_info,
            N_err_state_out_Idle_fault_out_faulty_packet_in,
            N_err_state_out_Idle_not_health_info,
            N_err_state_out_Idle_not_write_fake_flit,

            N_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
            N_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
            N_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
            N_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
            N_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            N_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
            N_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
            N_err_state_out_Header_flit_valid_in_fault_out_fault_info,
            N_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
            N_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
            N_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            N_err_state_out_Header_flit_not_valid_in_not_fault_info,
            N_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
            N_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

            N_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
            N_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
            N_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
            N_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
            N_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
            N_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            N_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
            N_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
            N_err_state_out_Body_flit_valid_in_fault_out_fault_info,
            N_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
            N_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
            N_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            N_err_state_out_Body_flit_not_valid_in_not_fault_info,
            N_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
            N_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
            N_err_state_out_Body_flit_valid_in_not_health_info,
            N_err_state_out_Body_flit_not_fake_credit,
            N_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

            N_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
            N_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
            N_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
            N_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            N_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
            N_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
            N_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
            N_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
            N_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
            N_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
            N_err_state_out_Tail_flit_not_valid_in_not_fault_info,
            N_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
            N_err_state_out_Tail_flit_not_write_fake_flit,

            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            N_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
            N_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
            N_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
            N_err_state_out_Packet_drop_not_fault_info,
            N_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
            N_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change : std_logic;

            -- East

            -- Functional checkers
   signal   E_err_empty_full,
            E_err_empty_read_en,
            E_err_full_write_en,
            E_err_state_in_onehot,
            E_err_read_pointer_in_onehot,
            E_err_write_pointer_in_onehot,

            -- Structural checkers
            E_err_write_en_write_pointer,
            E_err_not_write_en_write_pointer,
            E_err_read_pointer_write_pointer_not_empty,
            E_err_read_pointer_write_pointer_empty,
            E_err_read_pointer_write_pointer_not_full,
            E_err_read_pointer_write_pointer_full,
            E_err_read_pointer_increment,
            E_err_read_pointer_not_increment,
            E_err_write_en,
            E_err_not_write_en,
            E_err_not_write_en1,
            E_err_not_write_en2,
            E_err_read_en_mismatch,
            E_err_read_en_mismatch1,

            -- Newly added checkers for FIFO with packet drop and fault classifier support!
            E_err_fake_credit_read_en_fake_credit_counter_in_increment,
            E_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
            E_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
            E_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
            E_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
            E_err_fake_credit_read_en_credit_out,
            E_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
            E_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

            -- Checkers for Packet Dropping FSM of FIFO
            E_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
            E_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
            E_err_state_out_Idle_not_fault_out_not_fake_credit,
            E_err_state_out_Idle_not_fault_out_not_fault_info,
            E_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
            E_err_state_out_Idle_fault_out_fake_credit,
            E_err_state_out_Idle_fault_out_state_in_Packet_drop,
            E_err_state_out_Idle_fault_out_fault_info,
            E_err_state_out_Idle_fault_out_faulty_packet_in,
            E_err_state_out_Idle_not_health_info,
            E_err_state_out_Idle_not_write_fake_flit,

            E_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
            E_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
            E_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
            E_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
            E_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            E_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
            E_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
            E_err_state_out_Header_flit_valid_in_fault_out_fault_info,
            E_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
            E_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
            E_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            E_err_state_out_Header_flit_not_valid_in_not_fault_info,
            E_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
            E_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

            E_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
            E_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
            E_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
            E_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
            E_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
            E_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            E_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
            E_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
            E_err_state_out_Body_flit_valid_in_fault_out_fault_info,
            E_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
            E_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
            E_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            E_err_state_out_Body_flit_not_valid_in_not_fault_info,
            E_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
            E_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
            E_err_state_out_Body_flit_valid_in_not_health_info,
            E_err_state_out_Body_flit_not_fake_credit,
            E_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

            E_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
            E_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
            E_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
            E_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            E_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
            E_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
            E_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
            E_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
            E_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
            E_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
            E_err_state_out_Tail_flit_not_valid_in_not_fault_info,
            E_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
            E_err_state_out_Tail_flit_not_write_fake_flit,

            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            E_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
            E_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
            E_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
            E_err_state_out_Packet_drop_not_fault_info,
            E_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
            E_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change : std_logic;

            -- West

            -- Functional checkers
   signal   W_err_empty_full, W_err_empty_read_en, W_err_full_write_en, W_err_state_in_onehot,
            W_err_read_pointer_in_onehot, W_err_write_pointer_in_onehot,

            -- Structural checkers
            W_err_write_en_write_pointer,
            W_err_not_write_en_write_pointer,
            W_err_read_pointer_write_pointer_not_empty,
            W_err_read_pointer_write_pointer_empty,
            W_err_read_pointer_write_pointer_not_full,
            W_err_read_pointer_write_pointer_full,
            W_err_read_pointer_increment,
            W_err_read_pointer_not_increment,
            W_err_write_en,
            W_err_not_write_en,
            W_err_not_write_en1,
            W_err_not_write_en2,
            W_err_read_en_mismatch,
            W_err_read_en_mismatch1,

            -- Newly added checkers for FIFO with packet drop and fault classifier support!
            W_err_fake_credit_read_en_fake_credit_counter_in_increment,
            W_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
            W_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
            W_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
            W_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
            W_err_fake_credit_read_en_credit_out,
            W_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
            W_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

            -- Checkers for Packet Dropping FSM of FIFO
            W_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
            W_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
            W_err_state_out_Idle_not_fault_out_not_fake_credit,
            W_err_state_out_Idle_not_fault_out_not_fault_info,
            W_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
            W_err_state_out_Idle_fault_out_fake_credit,
            W_err_state_out_Idle_fault_out_state_in_Packet_drop,
            W_err_state_out_Idle_fault_out_fault_info,
            W_err_state_out_Idle_fault_out_faulty_packet_in,
            W_err_state_out_Idle_not_health_info,
            W_err_state_out_Idle_not_write_fake_flit,

            W_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
            W_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
            W_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
            W_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
            W_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            W_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
            W_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
            W_err_state_out_Header_flit_valid_in_fault_out_fault_info,
            W_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
            W_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
            W_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            W_err_state_out_Header_flit_not_valid_in_not_fault_info,
            W_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
            W_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

            W_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
            W_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
            W_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
            W_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
            W_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
            W_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            W_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
            W_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
            W_err_state_out_Body_flit_valid_in_fault_out_fault_info,
            W_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
            W_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
            W_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            W_err_state_out_Body_flit_not_valid_in_not_fault_info,
            W_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
            W_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
            W_err_state_out_Body_flit_valid_in_not_health_info,
            W_err_state_out_Body_flit_not_fake_credit,
            W_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

            W_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
            W_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
            W_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
            W_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            W_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
            W_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
            W_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
            W_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
            W_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
            W_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
            W_err_state_out_Tail_flit_not_valid_in_not_fault_info,
            W_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
            W_err_state_out_Tail_flit_not_write_fake_flit,

            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            W_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
            W_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
            W_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
            W_err_state_out_Packet_drop_not_fault_info,
            W_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
            W_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change : std_logic;

            -- South

            -- Functional checkers
   signal   S_err_empty_full, S_err_empty_read_en, S_err_full_write_en,
            S_err_state_in_onehot, S_err_read_pointer_in_onehot, S_err_write_pointer_in_onehot,

            -- Structural checkers
            S_err_write_en_write_pointer,
            S_err_not_write_en_write_pointer,
            S_err_read_pointer_write_pointer_not_empty,
            S_err_read_pointer_write_pointer_empty,
            S_err_read_pointer_write_pointer_not_full,
            S_err_read_pointer_write_pointer_full,
            S_err_read_pointer_increment,
            S_err_read_pointer_not_increment,
            S_err_write_en,
            S_err_not_write_en,
            S_err_not_write_en1,
            S_err_not_write_en2,
            S_err_read_en_mismatch,
            S_err_read_en_mismatch1,

            -- Newly added checkers for FIFO with packet drop and fault classifier support!
            S_err_fake_credit_read_en_fake_credit_counter_in_increment,
            S_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
            S_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
            S_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
            S_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
            S_err_fake_credit_read_en_credit_out,
            S_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
            S_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

            -- Checkers for Packet Dropping FSM of FIFO
            S_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
            S_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
            S_err_state_out_Idle_not_fault_out_not_fake_credit,
            S_err_state_out_Idle_not_fault_out_not_fault_info,
            S_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
            S_err_state_out_Idle_fault_out_fake_credit,
            S_err_state_out_Idle_fault_out_state_in_Packet_drop,
            S_err_state_out_Idle_fault_out_fault_info,
            S_err_state_out_Idle_fault_out_faulty_packet_in,
            S_err_state_out_Idle_not_health_info,
            S_err_state_out_Idle_not_write_fake_flit,

            S_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
            S_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
            S_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
            S_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
            S_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            S_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
            S_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
            S_err_state_out_Header_flit_valid_in_fault_out_fault_info,
            S_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
            S_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
            S_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            S_err_state_out_Header_flit_not_valid_in_not_fault_info,
            S_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
            S_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

            S_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
            S_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
            S_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
            S_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
            S_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
            S_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            S_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
            S_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
            S_err_state_out_Body_flit_valid_in_fault_out_fault_info,
            S_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
            S_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
            S_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            S_err_state_out_Body_flit_not_valid_in_not_fault_info,
            S_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
            S_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
            S_err_state_out_Body_flit_valid_in_not_health_info,
            S_err_state_out_Body_flit_not_fake_credit,
            S_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

            S_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
            S_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
            S_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
            S_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            S_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
            S_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
            S_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
            S_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
            S_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
            S_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
            S_err_state_out_Tail_flit_not_valid_in_not_fault_info,
            S_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
            S_err_state_out_Tail_flit_not_write_fake_flit,

            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            S_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
            S_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
            S_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
            S_err_state_out_Packet_drop_not_fault_info,
            S_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
            S_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change : std_logic;

            -- Local

            -- Functional checkers
   signal   L_err_empty_full,
            L_err_empty_read_en,
            L_err_full_write_en,
            L_err_state_in_onehot,
            L_err_read_pointer_in_onehot,
            L_err_write_pointer_in_onehot,

            -- Structural checkers
            L_err_write_en_write_pointer,
            L_err_not_write_en_write_pointer,
            L_err_read_pointer_write_pointer_not_empty,
            L_err_read_pointer_write_pointer_empty,
            L_err_read_pointer_write_pointer_not_full,
            L_err_read_pointer_write_pointer_full,
            L_err_read_pointer_increment,
            L_err_read_pointer_not_increment,
            L_err_write_en,
            L_err_not_write_en,
            L_err_not_write_en1,
            L_err_not_write_en2,
            L_err_read_en_mismatch,
            L_err_read_en_mismatch1,

            -- Newly added checkers for FIFO with packet drop and fault classifier support!
            L_err_fake_credit_read_en_fake_credit_counter_in_increment,
            L_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
            L_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
            L_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
            L_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
            L_err_fake_credit_read_en_credit_out,
            L_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
            L_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

            -- Checkers for Packet Dropping FSM of FIFO
            L_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
            L_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
            L_err_state_out_Idle_not_fault_out_not_fake_credit,
            L_err_state_out_Idle_not_fault_out_not_fault_info,
            L_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
            L_err_state_out_Idle_fault_out_fake_credit,
            L_err_state_out_Idle_fault_out_state_in_Packet_drop,
            L_err_state_out_Idle_fault_out_fault_info,
            L_err_state_out_Idle_fault_out_faulty_packet_in,
            L_err_state_out_Idle_not_health_info,
            L_err_state_out_Idle_not_write_fake_flit,

            L_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
            L_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
            L_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
            L_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
            L_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            L_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
            L_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
            L_err_state_out_Header_flit_valid_in_fault_out_fault_info,
            L_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
            L_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
            L_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            L_err_state_out_Header_flit_not_valid_in_not_fault_info,
            L_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
            L_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

            L_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
            L_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
            L_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
            L_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
            L_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
            L_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            L_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
            L_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
            L_err_state_out_Body_flit_valid_in_fault_out_fault_info,
            L_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
            L_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
            L_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            L_err_state_out_Body_flit_not_valid_in_not_fault_info,
            L_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
            L_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
            L_err_state_out_Body_flit_valid_in_not_health_info,
            L_err_state_out_Body_flit_not_fake_credit,
            L_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

            L_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
            L_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
            L_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
            L_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            L_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
            L_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
            L_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
            L_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
            L_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
            L_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
            L_err_state_out_Tail_flit_not_valid_in_not_fault_info,
            L_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
            L_err_state_out_Tail_flit_not_write_fake_flit,

            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            L_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
            L_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
            L_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
            L_err_state_out_Packet_drop_not_fault_info,
            L_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
            L_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change : std_logic;

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

    -- Signals needed for Allocator unit

    -- Allocator logic checker outputs
    signal  err_grant_N_N_sig_not_empty_N_grant_N_N, err_not_grant_N_N_sig_or_empty_N_not_grant_N_N,
            err_grant_N_E_sig_not_empty_E_grant_N_E, err_not_grant_N_E_sig_or_empty_E_not_grant_N_E,
            err_grant_N_W_sig_not_empty_W_grant_N_W, err_not_grant_N_W_sig_or_empty_W_not_grant_N_W,
            err_grant_N_S_sig_not_empty_S_grant_N_S, err_not_grant_N_S_sig_or_empty_S_not_grant_N_S,
            err_grant_N_L_sig_not_empty_L_grant_N_L, err_not_grant_N_L_sig_or_empty_L_not_grant_N_L,

            err_grant_E_N_sig_not_empty_N_grant_E_N, err_not_grant_E_N_sig_or_empty_N_not_grant_E_N,
            err_grant_E_E_sig_not_empty_E_grant_E_E, err_not_grant_E_E_sig_or_empty_E_not_grant_E_E,
            err_grant_E_W_sig_not_empty_W_grant_E_W, err_not_grant_E_W_sig_or_empty_W_not_grant_E_W,
            err_grant_E_S_sig_not_empty_S_grant_E_S, err_not_grant_E_S_sig_or_empty_S_not_grant_E_S,
            err_grant_E_L_sig_not_empty_L_grant_E_L, err_not_grant_E_L_sig_or_empty_L_not_grant_E_L,

            err_grant_W_N_sig_not_empty_N_grant_W_N,
            err_not_grant_W_N_sig_or_empty_N_not_grant_W_N,
            err_grant_W_E_sig_not_empty_E_grant_W_E,
            err_not_grant_W_E_sig_or_empty_E_not_grant_W_E,
            err_grant_W_W_sig_not_empty_W_grant_W_W,
            err_not_grant_W_W_sig_or_empty_W_not_grant_W_W,
            err_grant_W_S_sig_not_empty_S_grant_W_S,
            err_not_grant_W_S_sig_or_empty_S_not_grant_W_S,
            err_grant_W_L_sig_not_empty_L_grant_W_L,
            err_not_grant_W_L_sig_or_empty_L_not_grant_W_L,

            err_grant_S_N_sig_not_empty_N_grant_S_N,
            err_not_grant_S_N_sig_or_empty_N_not_grant_S_N,
            err_grant_S_E_sig_not_empty_E_grant_S_E,
            err_not_grant_S_E_sig_or_empty_E_not_grant_S_E,
            err_grant_S_W_sig_not_empty_W_grant_S_W,
            err_not_grant_S_W_sig_or_empty_W_not_grant_S_W,
            err_grant_S_S_sig_not_empty_S_grant_S_S,
            err_not_grant_S_S_sig_or_empty_S_not_grant_S_S,
            err_grant_S_L_sig_not_empty_L_grant_S_L,
            err_not_grant_S_L_sig_or_empty_L_not_grant_S_L,

            err_grant_L_N_sig_not_empty_N_grant_L_N,
            err_not_grant_L_N_sig_or_empty_N_not_grant_L_N,
            err_grant_L_E_sig_not_empty_E_grant_L_E,
            err_not_grant_L_E_sig_or_empty_E_not_grant_L_E,
            err_grant_L_W_sig_not_empty_W_grant_L_W,
            err_not_grant_L_W_sig_or_empty_W_not_grant_L_W,
            err_grant_L_S_sig_not_empty_S_grant_L_S,
            err_not_grant_L_S_sig_or_empty_S_not_grant_L_S,
            err_grant_L_L_sig_not_empty_L_grant_L_L,
            err_not_grant_L_L_sig_or_empty_L_not_grant_L_L,

            err_grant_signals_not_empty_grant_N,
            err_not_grant_signals_empty_not_grant_N,
            err_grant_signals_not_empty_grant_E,
            err_not_grant_signals_empty_not_grant_E,
            err_grant_signals_not_empty_grant_W,
            err_not_grant_signals_empty_not_grant_W,
            err_grant_signals_not_empty_grant_S,
            err_not_grant_signals_empty_not_grant_S,
            err_grant_signals_not_empty_grant_L,
            err_not_grant_signals_empty_not_grant_L,

            err_grants_valid_not_match: std_logic;

    -- Allocator credit_counter logic checker outputs
    signal  err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal,
            err_credit_in_N_credit_counter_N_out_increment,
            err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change,
            err_grant_N_credit_counter_N_out_decrement,
            err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change,
            err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal,

            err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal,
            err_credit_in_E_credit_counter_E_out_increment,
            err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change,
            err_grant_E_credit_counter_E_out_decrement,
            err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change,
            err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal,

            err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal,
            err_credit_in_W_credit_counter_W_out_increment,
            err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change,
            err_grant_W_credit_counter_W_out_decrement,
            err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change,
            err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal,

            err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal,
            err_credit_in_S_credit_counter_S_out_increment,
            err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change,
            err_grant_S_credit_counter_S_out_decrement,
            err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change,
            err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal,

            err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal,
            err_credit_in_L_credit_counter_L_out_increment,
            err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change,
            err_grant_L_credit_counter_L_out_decrement,
            err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change,
            err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal : std_logic;

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------

            -- Arbiter_in Checker signals (part of allocator unit)

            -- North Arbiter_in checker outputs
    signal  N_err_Requests_state_in_state_not_equal,

            N_err_IDLE_Req_N, N_err_IDLE_grant_N,N_err_North_Req_N, N_err_North_grant_N, N_err_East_Req_E, N_err_East_grant_E,
            N_err_West_Req_W, N_err_West_grant_W, N_err_South_Req_S,N_err_South_grant_S,N_err_Local_Req_L, N_err_Local_grant_L,

            N_err_IDLE_Req_E, N_err_IDLE_grant_E, N_err_North_Req_E, N_err_North_grant_E, N_err_East_Req_W, N_err_East_grant_W,
            N_err_West_Req_S, N_err_West_grant_S, N_err_South_Req_L, N_err_South_grant_L, N_err_Local_Req_N, N_err_Local_grant_N,

            N_err_IDLE_Req_W, N_err_IDLE_grant_W, N_err_North_Req_W, N_err_North_grant_W, N_err_East_Req_S, N_err_East_grant_S,
            N_err_West_Req_L, N_err_West_grant_L, N_err_South_Req_N,  N_err_South_grant_N, N_err_Local_Req_E, N_err_Local_grant_E,

            N_err_IDLE_Req_S, N_err_IDLE_grant_S, N_err_North_Req_S, N_err_North_grant_S, N_err_East_Req_L, N_err_East_grant_L,
            N_err_West_Req_N, N_err_West_grant_N, N_err_South_Req_E, N_err_South_grant_E, N_err_Local_Req_W, N_err_Local_grant_W,

            N_err_IDLE_Req_L, N_err_IDLE_grant_L, N_err_North_Req_L, N_err_North_grant_L, N_err_East_Req_N, N_err_East_grant_N,
            N_err_West_Req_E, N_err_West_grant_E, N_err_South_Req_W, N_err_South_grant_W, N_err_Local_Req_S, N_err_Local_grant_S,

            N_err_arbiter_state_in_onehot, N_err_no_request_grants, N_err_request_no_grants,

            N_err_no_Req_N_grant_N, N_err_no_Req_E_grant_E,  N_err_no_Req_W_grant_W,  N_err_no_Req_S_grant_S, N_err_no_Req_L_grant_L,

            -- East Arbiter_in checker outputs
            E_err_Requests_state_in_state_not_equal,

            E_err_IDLE_Req_N, E_err_IDLE_grant_N,E_err_North_Req_N, E_err_North_grant_N, E_err_East_Req_E, E_err_East_grant_E,
            E_err_West_Req_W, E_err_West_grant_W, E_err_South_Req_S,E_err_South_grant_S,E_err_Local_Req_L, E_err_Local_grant_L,

            E_err_IDLE_Req_E, E_err_IDLE_grant_E, E_err_North_Req_E, E_err_North_grant_E, E_err_East_Req_W, E_err_East_grant_W,
            E_err_West_Req_S, E_err_West_grant_S, E_err_South_Req_L, E_err_South_grant_L, E_err_Local_Req_N, E_err_Local_grant_N,

            E_err_IDLE_Req_W, E_err_IDLE_grant_W, E_err_North_Req_W, E_err_North_grant_W, E_err_East_Req_S, E_err_East_grant_S,
            E_err_West_Req_L, E_err_West_grant_L, E_err_South_Req_N,  E_err_South_grant_N, E_err_Local_Req_E, E_err_Local_grant_E,

            E_err_IDLE_Req_S, E_err_IDLE_grant_S, E_err_North_Req_S, E_err_North_grant_S, E_err_East_Req_L, E_err_East_grant_L,
            E_err_West_Req_N, E_err_West_grant_N, E_err_South_Req_E, E_err_South_grant_E, E_err_Local_Req_W, E_err_Local_grant_W,

            E_err_IDLE_Req_L, E_err_IDLE_grant_L, E_err_North_Req_L, E_err_North_grant_L, E_err_East_Req_N, E_err_East_grant_N,
            E_err_West_Req_E, E_err_West_grant_E, E_err_South_Req_W, E_err_South_grant_W, E_err_Local_Req_S, E_err_Local_grant_S,

            E_err_arbiter_state_in_onehot, E_err_no_request_grants, E_err_request_no_grants,

            E_err_no_Req_N_grant_N,E_err_no_Req_E_grant_E, E_err_no_Req_W_grant_W, E_err_no_Req_S_grant_S, E_err_no_Req_L_grant_L,

            -- West Arbiter_in checker outputs
            W_err_Requests_state_in_state_not_equal,

            W_err_IDLE_Req_N, W_err_IDLE_grant_N,W_err_North_Req_N, W_err_North_grant_N, W_err_East_Req_E, W_err_East_grant_E,
            W_err_West_Req_W, W_err_West_grant_W, W_err_South_Req_S,W_err_South_grant_S,W_err_Local_Req_L, W_err_Local_grant_L,

            W_err_IDLE_Req_E, W_err_IDLE_grant_E, W_err_North_Req_E, W_err_North_grant_E, W_err_East_Req_W, W_err_East_grant_W,
            W_err_West_Req_S, W_err_West_grant_S, W_err_South_Req_L, W_err_South_grant_L, W_err_Local_Req_N, W_err_Local_grant_N,

            W_err_IDLE_Req_W, W_err_IDLE_grant_W, W_err_North_Req_W, W_err_North_grant_W, W_err_East_Req_S, W_err_East_grant_S,
            W_err_West_Req_L, W_err_West_grant_L, W_err_South_Req_N,  W_err_South_grant_N, W_err_Local_Req_E, W_err_Local_grant_E,

            W_err_IDLE_Req_S, W_err_IDLE_grant_S, W_err_North_Req_S, W_err_North_grant_S, W_err_East_Req_L, W_err_East_grant_L,
            W_err_West_Req_N, W_err_West_grant_N, W_err_South_Req_E, W_err_South_grant_E, W_err_Local_Req_W, W_err_Local_grant_W,

            W_err_IDLE_Req_L, W_err_IDLE_grant_L, W_err_North_Req_L, W_err_North_grant_L, W_err_East_Req_N, W_err_East_grant_N,
            W_err_West_Req_E, W_err_West_grant_E, W_err_South_Req_W, W_err_South_grant_W, W_err_Local_Req_S, W_err_Local_grant_S,

            W_err_arbiter_state_in_onehot, W_err_no_request_grants, W_err_request_no_grants,

            W_err_no_Req_N_grant_N, W_err_no_Req_E_grant_E,  W_err_no_Req_W_grant_W,  W_err_no_Req_S_grant_S,  W_err_no_Req_L_grant_L,

            -- South Arbiter_in checker outputs
            S_err_Requests_state_in_state_not_equal,

            S_err_IDLE_Req_N, S_err_IDLE_grant_N,S_err_North_Req_N, S_err_North_grant_N, S_err_East_Req_E, S_err_East_grant_E,
            S_err_West_Req_W, S_err_West_grant_W, S_err_South_Req_S,S_err_South_grant_S,S_err_Local_Req_L, S_err_Local_grant_L,

            S_err_IDLE_Req_E, S_err_IDLE_grant_E, S_err_North_Req_E, S_err_North_grant_E, S_err_East_Req_W, S_err_East_grant_W,
            S_err_West_Req_S, S_err_West_grant_S, S_err_South_Req_L, S_err_South_grant_L, S_err_Local_Req_N, S_err_Local_grant_N,

            S_err_IDLE_Req_W, S_err_IDLE_grant_W, S_err_North_Req_W, S_err_North_grant_W, S_err_East_Req_S, S_err_East_grant_S,
            S_err_West_Req_L, S_err_West_grant_L, S_err_South_Req_N,  S_err_South_grant_N, S_err_Local_Req_E, S_err_Local_grant_E,

            S_err_IDLE_Req_S, S_err_IDLE_grant_S, S_err_North_Req_S, S_err_North_grant_S, S_err_East_Req_L, S_err_East_grant_L,
            S_err_West_Req_N, S_err_West_grant_N, S_err_South_Req_E, S_err_South_grant_E, S_err_Local_Req_W, S_err_Local_grant_W,

            S_err_IDLE_Req_L, S_err_IDLE_grant_L, S_err_North_Req_L, S_err_North_grant_L, S_err_East_Req_N, S_err_East_grant_N,
            S_err_West_Req_E, S_err_West_grant_E, S_err_South_Req_W, S_err_South_grant_W, S_err_Local_Req_S, S_err_Local_grant_S,

            S_err_arbiter_state_in_onehot, S_err_no_request_grants, S_err_request_no_grants,

            S_err_no_Req_N_grant_N, S_err_no_Req_E_grant_E, S_err_no_Req_W_grant_W, S_err_no_Req_S_grant_S, S_err_no_Req_L_grant_L,

            -- Local Arbiter_in checker outputs
            L_err_Requests_state_in_state_not_equal,

            L_err_IDLE_Req_N, L_err_IDLE_grant_N,L_err_North_Req_N, L_err_North_grant_N, L_err_East_Req_E, L_err_East_grant_E,
            L_err_West_Req_W, L_err_West_grant_W, L_err_South_Req_S,L_err_South_grant_S,L_err_Local_Req_L, L_err_Local_grant_L,

            L_err_IDLE_Req_E, L_err_IDLE_grant_E, L_err_North_Req_E, L_err_North_grant_E, L_err_East_Req_W, L_err_East_grant_W,
            L_err_West_Req_S, L_err_West_grant_S, L_err_South_Req_L, L_err_South_grant_L, L_err_Local_Req_N, L_err_Local_grant_N,

            L_err_IDLE_Req_W, L_err_IDLE_grant_W, L_err_North_Req_W, L_err_North_grant_W, L_err_East_Req_S, L_err_East_grant_S,
            L_err_West_Req_L, L_err_West_grant_L, L_err_South_Req_N,  L_err_South_grant_N, L_err_Local_Req_E, L_err_Local_grant_E,

            L_err_IDLE_Req_S, L_err_IDLE_grant_S, L_err_North_Req_S, L_err_North_grant_S, L_err_East_Req_L, L_err_East_grant_L,
            L_err_West_Req_N, L_err_West_grant_N, L_err_South_Req_E, L_err_South_grant_E, L_err_Local_Req_W, L_err_Local_grant_W,

            L_err_IDLE_Req_L, L_err_IDLE_grant_L, L_err_North_Req_L, L_err_North_grant_L, L_err_East_Req_N, L_err_East_grant_N,
            L_err_West_Req_E, L_err_West_grant_E, L_err_South_Req_W, L_err_South_grant_W, L_err_Local_Req_S, L_err_Local_grant_S,

            L_err_arbiter_state_in_onehot,
            L_err_no_request_grants,
            L_err_request_no_grants,

            L_err_no_Req_N_grant_N,
            L_err_no_Req_E_grant_E,
            L_err_no_Req_W_grant_W,
            L_err_no_Req_S_grant_S,
            L_err_no_Req_L_grant_L : std_logic;

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------

            -- Arbiter_out Checker signals (part of allocator unit)

            -- North Arbiter_out checker outputs
    signal  N_arbiter_out_err_Requests_state_in_state_not_equal,

            N_err_IDLE_req_X_N,
            N_err_North_req_X_N,
            N_err_North_credit_not_zero_req_X_N_grant_N,
            N_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            N_err_East_req_X_E,
            N_err_East_credit_not_zero_req_X_E_grant_E,
            N_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            N_err_West_req_X_W,
            N_err_West_credit_not_zero_req_X_W_grant_W,
            N_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            N_err_South_req_X_S,
            N_err_South_credit_not_zero_req_X_S_grant_S,
            N_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            N_err_Local_req_X_L,
            N_err_Local_credit_not_zero_req_X_L_grant_L,
            N_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            N_err_IDLE_req_X_E, N_err_North_req_X_E, N_err_East_req_X_W, N_err_West_req_X_S, N_err_South_req_X_L, N_err_Local_req_X_N,
            N_err_IDLE_req_X_W, N_err_North_req_X_W, N_err_East_req_X_S, N_err_West_req_X_L, N_err_South_req_X_N, N_err_Local_req_X_E,
            N_err_IDLE_req_X_S, N_err_North_req_X_S, N_err_East_req_X_L, N_err_West_req_X_N, N_err_South_req_X_E, N_err_Local_req_X_W,
            N_err_IDLE_req_X_L, N_err_North_req_X_L, N_err_East_req_X_N, N_err_West_req_X_E, N_err_South_req_X_W, N_err_Local_req_X_S,

            N_arbiter_out_err_state_in_onehot,
            N_arbiter_out_err_no_request_grants,
            N_err_request_IDLE_state,

            N_err_request_IDLE_not_Grants, N_err_state_North_Invalid_Grant,N_err_state_East_Invalid_Grant,
            N_err_state_West_Invalid_Grant, N_err_state_South_Invalid_Grant,N_err_state_Local_Invalid_Grant,
            N_err_Grants_onehot_or_all_zero,

            -- East Arbiter_out checker outputs
            E_arbiter_out_err_Requests_state_in_state_not_equal,

            E_err_IDLE_req_X_N,
            E_err_North_req_X_N,
            E_err_North_credit_not_zero_req_X_N_grant_N,
            E_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            E_err_East_req_X_E,
            E_err_East_credit_not_zero_req_X_E_grant_E,
            E_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            E_err_West_req_X_W,
            E_err_West_credit_not_zero_req_X_W_grant_W,
            E_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            E_err_South_req_X_S,
            E_err_South_credit_not_zero_req_X_S_grant_S,
            E_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            E_err_Local_req_X_L,
            E_err_Local_credit_not_zero_req_X_L_grant_L,
            E_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            E_err_IDLE_req_X_E, E_err_North_req_X_E, E_err_East_req_X_W, E_err_West_req_X_S, E_err_South_req_X_L, E_err_Local_req_X_N,
            E_err_IDLE_req_X_W, E_err_North_req_X_W, E_err_East_req_X_S, E_err_West_req_X_L, E_err_South_req_X_N, E_err_Local_req_X_E,
            E_err_IDLE_req_X_S, E_err_North_req_X_S, E_err_East_req_X_L, E_err_West_req_X_N, E_err_South_req_X_E, E_err_Local_req_X_W,
            E_err_IDLE_req_X_L, E_err_North_req_X_L, E_err_East_req_X_N, E_err_West_req_X_E, E_err_South_req_X_W, E_err_Local_req_X_S,

            E_arbiter_out_err_state_in_onehot, E_arbiter_out_err_no_request_grants, E_err_request_IDLE_state,

            E_err_request_IDLE_not_Grants, E_err_state_North_Invalid_Grant,E_err_state_East_Invalid_Grant,
            E_err_state_West_Invalid_Grant, E_err_state_South_Invalid_Grant,E_err_state_Local_Invalid_Grant,
            E_err_Grants_onehot_or_all_zero,

            -- West Arbiter_out checker outputs
            W_arbiter_out_err_Requests_state_in_state_not_equal,

            W_err_IDLE_req_X_N,
            W_err_North_req_X_N,
            W_err_North_credit_not_zero_req_X_N_grant_N,
            W_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            W_err_East_req_X_E,
            W_err_East_credit_not_zero_req_X_E_grant_E,
            W_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            W_err_West_req_X_W,
            W_err_West_credit_not_zero_req_X_W_grant_W,
            W_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            W_err_South_req_X_S,
            W_err_South_credit_not_zero_req_X_S_grant_S,
            W_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            W_err_Local_req_X_L,
            W_err_Local_credit_not_zero_req_X_L_grant_L,
            W_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            W_err_IDLE_req_X_E, W_err_North_req_X_E, W_err_East_req_X_W, W_err_West_req_X_S, W_err_South_req_X_L, W_err_Local_req_X_N,
            W_err_IDLE_req_X_W, W_err_North_req_X_W, W_err_East_req_X_S, W_err_West_req_X_L, W_err_South_req_X_N, W_err_Local_req_X_E,
            W_err_IDLE_req_X_S, W_err_North_req_X_S, W_err_East_req_X_L, W_err_West_req_X_N, W_err_South_req_X_E, W_err_Local_req_X_W,
            W_err_IDLE_req_X_L, W_err_North_req_X_L, W_err_East_req_X_N, W_err_West_req_X_E, W_err_South_req_X_W, W_err_Local_req_X_S,

            W_arbiter_out_err_state_in_onehot, W_arbiter_out_err_no_request_grants, W_err_request_IDLE_state,

            W_err_request_IDLE_not_Grants, W_err_state_North_Invalid_Grant,W_err_state_East_Invalid_Grant, W_err_state_West_Invalid_Grant, W_err_state_South_Invalid_Grant,W_err_state_Local_Invalid_Grant,W_err_Grants_onehot_or_all_zero,

            -- South Arbiter_out checker outputs
            S_arbiter_out_err_Requests_state_in_state_not_equal,

            S_err_IDLE_req_X_N,
            S_err_North_req_X_N,
            S_err_North_credit_not_zero_req_X_N_grant_N,
            S_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            S_err_East_req_X_E,
            S_err_East_credit_not_zero_req_X_E_grant_E,
            S_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            S_err_West_req_X_W,
            S_err_West_credit_not_zero_req_X_W_grant_W,
            S_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            S_err_South_req_X_S,
            S_err_South_credit_not_zero_req_X_S_grant_S,
            S_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            S_err_Local_req_X_L,
            S_err_Local_credit_not_zero_req_X_L_grant_L,
            S_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            S_err_IDLE_req_X_E, S_err_North_req_X_E, S_err_East_req_X_W, S_err_West_req_X_S, S_err_South_req_X_L, S_err_Local_req_X_N,
            S_err_IDLE_req_X_W, S_err_North_req_X_W, S_err_East_req_X_S, S_err_West_req_X_L, S_err_South_req_X_N, S_err_Local_req_X_E,
            S_err_IDLE_req_X_S, S_err_North_req_X_S, S_err_East_req_X_L, S_err_West_req_X_N, S_err_South_req_X_E, S_err_Local_req_X_W,
            S_err_IDLE_req_X_L, S_err_North_req_X_L, S_err_East_req_X_N, S_err_West_req_X_E, S_err_South_req_X_W, S_err_Local_req_X_S,

            S_arbiter_out_err_state_in_onehot,
            S_arbiter_out_err_no_request_grants,
            S_err_request_IDLE_state,

            S_err_request_IDLE_not_Grants,
            S_err_state_North_Invalid_Grant,
            S_err_state_East_Invalid_Grant,
            S_err_state_West_Invalid_Grant,
            S_err_state_South_Invalid_Grant,
            S_err_state_Local_Invalid_Grant,
            S_err_Grants_onehot_or_all_zero,

            -- Local Arbiter_out checker outputs
            L_arbiter_out_err_Requests_state_in_state_not_equal,

            L_err_IDLE_req_X_N,
            L_err_North_req_X_N,
            L_err_North_credit_not_zero_req_X_N_grant_N,
            L_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            L_err_East_req_X_E,
            L_err_East_credit_not_zero_req_X_E_grant_E,
            L_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            L_err_West_req_X_W,
            L_err_West_credit_not_zero_req_X_W_grant_W,
            L_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            L_err_South_req_X_S,
            L_err_South_credit_not_zero_req_X_S_grant_S,
            L_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            L_err_Local_req_X_L,
            L_err_Local_credit_not_zero_req_X_L_grant_L,
            L_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            L_err_IDLE_req_X_E, L_err_North_req_X_E, L_err_East_req_X_W, L_err_West_req_X_S, L_err_South_req_X_L, L_err_Local_req_X_N,
            L_err_IDLE_req_X_W, L_err_North_req_X_W, L_err_East_req_X_S, L_err_West_req_X_L, L_err_South_req_X_N, L_err_Local_req_X_E,
            L_err_IDLE_req_X_S, L_err_North_req_X_S, L_err_East_req_X_L, L_err_West_req_X_N, L_err_South_req_X_E, L_err_Local_req_X_W,
            L_err_IDLE_req_X_L, L_err_North_req_X_L, L_err_East_req_X_N, L_err_West_req_X_E, L_err_South_req_X_W, L_err_Local_req_X_S,

            L_arbiter_out_err_state_in_onehot, L_arbiter_out_err_no_request_grants, L_err_request_IDLE_state,

            L_err_request_IDLE_not_Grants, L_err_state_North_Invalid_Grant,L_err_state_East_Invalid_Grant, L_err_state_West_Invalid_Grant,
            L_err_state_South_Invalid_Grant,L_err_state_Local_Invalid_Grant,L_err_Grants_onehot_or_all_zero : std_logic;

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------

-- Signals needed for grouping checkers to model turn/path faults

signal      N_FIFO_checkers_ORed, E_FIFO_checkers_ORed, W_FIFO_checkers_ORed, S_FIFO_checkers_ORed, L_FIFO_checkers_ORed : std_logic;
signal      N2E_turn_fault, N2W_turn_fault, E2N_turn_fault, E2S_turn_fault, W2N_turn_fault, W2S_turn_fault, S2E_turn_fault, S2W_turn_fault : std_logic;
signal      N2S_path_fault, S2N_path_fault, E2W_path_fault, W2E_path_fault : std_logic;
signal      L2N_fault, L2E_fault, L2W_fault, L2S_fault, N2L_fault, E2L_fault, W2L_fault, S2L_fault : std_logic;

begin


-- FIFO contributes to all turns and paths, therefore, for each turn or path (for the input direction), all the outputs of FIFO checkers
-- corresponding to that input are ORed together.

                            -- Functional checkers
N_FIFO_checkers_ORed  <=    N_err_empty_full or
                            N_err_empty_read_en or
                            N_err_full_write_en or
                            N_err_state_in_onehot or
                            N_err_read_pointer_in_onehot or
                            N_err_write_pointer_in_onehot or

                            -- Structural checkers
                            N_err_write_en_write_pointer or
                            N_err_not_write_en_write_pointer or
                            N_err_read_pointer_write_pointer_not_empty or
                            N_err_read_pointer_write_pointer_empty or
                            N_err_read_pointer_write_pointer_not_full or
                            N_err_read_pointer_write_pointer_full or
                            N_err_read_pointer_increment or
                            N_err_read_pointer_not_increment or
                            N_err_write_en or
                            N_err_not_write_en or
                            N_err_not_write_en1 or
                            N_err_not_write_en2 or
                            N_err_read_en_mismatch or
                            N_err_read_en_mismatch1 or

                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                            N_err_fake_credit_read_en_fake_credit_counter_in_increment or
                            N_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement or
                            N_err_not_fake_credit_read_en_fake_credit_counter_in_not_change or
                            N_err_fake_credit_not_read_en_fake_credit_counter_in_not_change or
                            N_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change or
                            N_err_fake_credit_read_en_credit_out or
                            N_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out or
                            N_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out or

                            -- Checkers for Packet Dropping FSM of FIFO
                            N_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit or
                            N_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change or
                            N_err_state_out_Idle_not_fault_out_not_fake_credit or
                            N_err_state_out_Idle_not_fault_out_not_fault_info or
                            N_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal or
                            N_err_state_out_Idle_fault_out_fake_credit or
                            N_err_state_out_Idle_fault_out_state_in_Packet_drop or
                            N_err_state_out_Idle_fault_out_fault_info or
                            N_err_state_out_Idle_fault_out_faulty_packet_in or
                            N_err_state_out_Idle_not_health_info or
                            N_err_state_out_Idle_not_write_fake_flit or

                            N_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit or
                            N_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit or
                            N_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit or
                            N_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info or
                            N_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            N_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit or
                            N_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop or
                            N_err_state_out_Header_flit_valid_in_fault_out_fault_info or
                            N_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in or
                            N_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change or
                            N_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            N_err_state_out_Header_flit_not_valid_in_not_fault_info or
                            N_err_state_out_Header_flit_not_valid_in_not_write_fake_flit or
                            N_err_state_out_Header_flit_or_Body_flit_not_fake_credit or

                            N_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change or
                            N_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit or
                            N_err_state_out_Body_flit_valid_in_not_fault_out_health_info or
                            N_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit or
                            N_err_state_out_Body_flit_valid_in_not_fault_out_fault_info or
                            N_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            N_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit or
                            N_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop or
                            N_err_state_out_Body_flit_valid_in_fault_out_fault_info or
                            N_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in or
                            N_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change or
                            N_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            N_err_state_out_Body_flit_not_valid_in_not_fault_info or
                            N_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info or
                            N_err_state_out_Body_flit_valid_in_fault_out_not_health_info or
                            N_err_state_out_Body_flit_valid_in_not_health_info or
                            N_err_state_out_Body_flit_not_fake_credit or
                            N_err_state_out_Body_flit_not_valid_in_not_write_fake_flit or

                            N_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit or
                            N_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit or
                            N_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info or
                            N_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            N_err_state_out_Tail_flit_valid_in_fault_out_fake_credit or
                            N_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop or
                            N_err_state_out_Tail_flit_valid_in_fault_out_fault_info or
                            N_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in or
                            N_err_state_out_Tail_flit_not_valid_in_state_in_Idle or
                            N_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change or
                            N_err_state_out_Tail_flit_not_valid_in_not_fault_info or
                            N_err_state_out_Tail_flit_not_valid_in_not_fake_credit or
                            N_err_state_out_Tail_flit_not_write_fake_flit or

                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit or
                            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            N_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change or
                            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal or
                            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change or
                            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit or
                            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit or
                            N_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change or
                            N_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change or
                            N_err_state_out_Packet_drop_not_fault_info or
                            N_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit or
                            N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit or
                            N_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change or
                            N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change;

                            -- Functional checkers
E_FIFO_checkers_ORed  <=    E_err_empty_full or
                            E_err_empty_read_en or
                            E_err_full_write_en or
                            E_err_state_in_onehot or
                            E_err_read_pointer_in_onehot or
                            E_err_write_pointer_in_onehot or

                            -- Structural checkers
                            E_err_write_en_write_pointer or
                            E_err_not_write_en_write_pointer or
                            E_err_read_pointer_write_pointer_not_empty or
                            E_err_read_pointer_write_pointer_empty or
                            E_err_read_pointer_write_pointer_not_full or
                            E_err_read_pointer_write_pointer_full or
                            E_err_read_pointer_increment or
                            E_err_read_pointer_not_increment or
                            E_err_write_en or
                            E_err_not_write_en or
                            E_err_not_write_en1 or
                            E_err_not_write_en2 or
                            E_err_read_en_mismatch or
                            E_err_read_en_mismatch1 or

                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                            E_err_fake_credit_read_en_fake_credit_counter_in_increment or
                            E_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement or
                            E_err_not_fake_credit_read_en_fake_credit_counter_in_not_change or
                            E_err_fake_credit_not_read_en_fake_credit_counter_in_not_change or
                            E_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change or
                            E_err_fake_credit_read_en_credit_out or
                            E_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out or
                            E_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out or

                            -- Checkers for Packet Dropping FSM of FIFO
                            E_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit or
                            E_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change or
                            E_err_state_out_Idle_not_fault_out_not_fake_credit or
                            E_err_state_out_Idle_not_fault_out_not_fault_info or
                            E_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal or
                            E_err_state_out_Idle_fault_out_fake_credit or
                            E_err_state_out_Idle_fault_out_state_in_Packet_drop or
                            E_err_state_out_Idle_fault_out_fault_info or
                            E_err_state_out_Idle_fault_out_faulty_packet_in or
                            E_err_state_out_Idle_not_health_info or
                            E_err_state_out_Idle_not_write_fake_flit or

                            E_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit or
                            E_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit or
                            E_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit or
                            E_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info or
                            E_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            E_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit or
                            E_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop or
                            E_err_state_out_Header_flit_valid_in_fault_out_fault_info or
                            E_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in or
                            E_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change or
                            E_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            E_err_state_out_Header_flit_not_valid_in_not_fault_info or
                            E_err_state_out_Header_flit_not_valid_in_not_write_fake_flit or
                            E_err_state_out_Header_flit_or_Body_flit_not_fake_credit or

                            E_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change or
                            E_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit or
                            E_err_state_out_Body_flit_valid_in_not_fault_out_health_info or
                            E_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit or
                            E_err_state_out_Body_flit_valid_in_not_fault_out_fault_info or
                            E_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            E_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit or
                            E_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop or
                            E_err_state_out_Body_flit_valid_in_fault_out_fault_info or
                            E_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in or
                            E_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change or
                            E_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            E_err_state_out_Body_flit_not_valid_in_not_fault_info or
                            E_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info or
                            E_err_state_out_Body_flit_valid_in_fault_out_not_health_info or
                            E_err_state_out_Body_flit_valid_in_not_health_info or
                            E_err_state_out_Body_flit_not_fake_credit or
                            E_err_state_out_Body_flit_not_valid_in_not_write_fake_flit or

                            E_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit or
                            E_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit or
                            E_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info or
                            E_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            E_err_state_out_Tail_flit_valid_in_fault_out_fake_credit or
                            E_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop or
                            E_err_state_out_Tail_flit_valid_in_fault_out_fault_info or
                            E_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in or
                            E_err_state_out_Tail_flit_not_valid_in_state_in_Idle or
                            E_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change or
                            E_err_state_out_Tail_flit_not_valid_in_not_fault_info or
                            E_err_state_out_Tail_flit_not_valid_in_not_fake_credit or
                            E_err_state_out_Tail_flit_not_write_fake_flit or

                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit or
                            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            E_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change or
                            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal or
                            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change or
                            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit or
                            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit or
                            E_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change or
                            E_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change or
                            E_err_state_out_Packet_drop_not_fault_info or
                            E_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit or
                            E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit or
                            E_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change or
                            E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change;

                            -- Functional checkers
W_FIFO_checkers_ORed  <=    W_err_empty_full or
                            W_err_empty_read_en or
                            W_err_full_write_en or
                            W_err_state_in_onehot or
                            W_err_read_pointer_in_onehot or
                            W_err_write_pointer_in_onehot or

                            -- Structural checkers
                            W_err_write_en_write_pointer or
                            W_err_not_write_en_write_pointer or
                            W_err_read_pointer_write_pointer_not_empty or
                            W_err_read_pointer_write_pointer_empty or
                            W_err_read_pointer_write_pointer_not_full or
                            W_err_read_pointer_write_pointer_full or
                            W_err_read_pointer_increment or
                            W_err_read_pointer_not_increment or
                            W_err_write_en or
                            W_err_not_write_en or
                            W_err_not_write_en1 or
                            W_err_not_write_en2 or
                            W_err_read_en_mismatch or
                            W_err_read_en_mismatch1 or

                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                            W_err_fake_credit_read_en_fake_credit_counter_in_increment or
                            W_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement or
                            W_err_not_fake_credit_read_en_fake_credit_counter_in_not_change or
                            W_err_fake_credit_not_read_en_fake_credit_counter_in_not_change or
                            W_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change or
                            W_err_fake_credit_read_en_credit_out or
                            W_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out or
                            W_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out or

                            -- Checkers for Packet Dropping FSM of FIFO
                            W_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit or
                            W_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change or
                            W_err_state_out_Idle_not_fault_out_not_fake_credit or
                            W_err_state_out_Idle_not_fault_out_not_fault_info or
                            W_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal or
                            W_err_state_out_Idle_fault_out_fake_credit or
                            W_err_state_out_Idle_fault_out_state_in_Packet_drop or
                            W_err_state_out_Idle_fault_out_fault_info or
                            W_err_state_out_Idle_fault_out_faulty_packet_in or
                            W_err_state_out_Idle_not_health_info or
                            W_err_state_out_Idle_not_write_fake_flit or

                            W_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit or
                            W_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit or
                            W_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit or
                            W_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info or
                            W_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            W_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit or
                            W_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop or
                            W_err_state_out_Header_flit_valid_in_fault_out_fault_info or
                            W_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in or
                            W_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change or
                            W_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            W_err_state_out_Header_flit_not_valid_in_not_fault_info or
                            W_err_state_out_Header_flit_not_valid_in_not_write_fake_flit or
                            W_err_state_out_Header_flit_or_Body_flit_not_fake_credit or

                            W_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change or
                            W_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit or
                            W_err_state_out_Body_flit_valid_in_not_fault_out_health_info or
                            W_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit or
                            W_err_state_out_Body_flit_valid_in_not_fault_out_fault_info or
                            W_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            W_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit or
                            W_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop or
                            W_err_state_out_Body_flit_valid_in_fault_out_fault_info or
                            W_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in or
                            W_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change or
                            W_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            W_err_state_out_Body_flit_not_valid_in_not_fault_info or
                            W_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info or
                            W_err_state_out_Body_flit_valid_in_fault_out_not_health_info or
                            W_err_state_out_Body_flit_valid_in_not_health_info or
                            W_err_state_out_Body_flit_not_fake_credit or
                            W_err_state_out_Body_flit_not_valid_in_not_write_fake_flit or

                            W_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit or
                            W_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit or
                            W_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info or
                            W_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            W_err_state_out_Tail_flit_valid_in_fault_out_fake_credit or
                            W_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop or
                            W_err_state_out_Tail_flit_valid_in_fault_out_fault_info or
                            W_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in or
                            W_err_state_out_Tail_flit_not_valid_in_state_in_Idle or
                            W_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change or
                            W_err_state_out_Tail_flit_not_valid_in_not_fault_info or
                            W_err_state_out_Tail_flit_not_valid_in_not_fake_credit or
                            W_err_state_out_Tail_flit_not_write_fake_flit or

                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit or
                            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            W_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change or
                            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal or
                            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change or
                            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit or
                            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit or
                            W_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change or
                            W_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change or
                            W_err_state_out_Packet_drop_not_fault_info or
                            W_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit or
                            W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit or
                            W_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change or
                            W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change;

                            -- Functional checkers
S_FIFO_checkers_ORed  <=    S_err_empty_full or
                            S_err_empty_read_en or
                            S_err_full_write_en or
                            S_err_state_in_onehot or
                            S_err_read_pointer_in_onehot or
                            S_err_write_pointer_in_onehot or

                            -- Structural checkers
                            S_err_write_en_write_pointer or
                            S_err_not_write_en_write_pointer or
                            S_err_read_pointer_write_pointer_not_empty or
                            S_err_read_pointer_write_pointer_empty or
                            S_err_read_pointer_write_pointer_not_full or
                            S_err_read_pointer_write_pointer_full or
                            S_err_read_pointer_increment or
                            S_err_read_pointer_not_increment or
                            S_err_write_en or
                            S_err_not_write_en or
                            S_err_not_write_en1 or
                            S_err_not_write_en2 or
                            S_err_read_en_mismatch or
                            S_err_read_en_mismatch1 or

                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                            S_err_fake_credit_read_en_fake_credit_counter_in_increment or
                            S_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement or
                            S_err_not_fake_credit_read_en_fake_credit_counter_in_not_change or
                            S_err_fake_credit_not_read_en_fake_credit_counter_in_not_change or
                            S_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change or
                            S_err_fake_credit_read_en_credit_out or
                            S_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out or
                            S_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out or

                            -- Checkers for Packet Dropping FSM of FIFO
                            S_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit or
                            S_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change or
                            S_err_state_out_Idle_not_fault_out_not_fake_credit or
                            S_err_state_out_Idle_not_fault_out_not_fault_info or
                            S_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal or
                            S_err_state_out_Idle_fault_out_fake_credit or
                            S_err_state_out_Idle_fault_out_state_in_Packet_drop or
                            S_err_state_out_Idle_fault_out_fault_info or
                            S_err_state_out_Idle_fault_out_faulty_packet_in or
                            S_err_state_out_Idle_not_health_info or
                            S_err_state_out_Idle_not_write_fake_flit or

                            S_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit or
                            S_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit or
                            S_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit or
                            S_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info or
                            S_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            S_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit or
                            S_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop or
                            S_err_state_out_Header_flit_valid_in_fault_out_fault_info or
                            S_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in or
                            S_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change or
                            S_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            S_err_state_out_Header_flit_not_valid_in_not_fault_info or
                            S_err_state_out_Header_flit_not_valid_in_not_write_fake_flit or
                            S_err_state_out_Header_flit_or_Body_flit_not_fake_credit or

                            S_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change or
                            S_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit or
                            S_err_state_out_Body_flit_valid_in_not_fault_out_health_info or
                            S_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit or
                            S_err_state_out_Body_flit_valid_in_not_fault_out_fault_info or
                            S_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            S_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit or
                            S_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop or
                            S_err_state_out_Body_flit_valid_in_fault_out_fault_info or
                            S_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in or
                            S_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change or
                            S_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            S_err_state_out_Body_flit_not_valid_in_not_fault_info or
                            S_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info or
                            S_err_state_out_Body_flit_valid_in_fault_out_not_health_info or
                            S_err_state_out_Body_flit_valid_in_not_health_info or
                            S_err_state_out_Body_flit_not_fake_credit or
                            S_err_state_out_Body_flit_not_valid_in_not_write_fake_flit or

                            S_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit or
                            S_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit or
                            S_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info or
                            S_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            S_err_state_out_Tail_flit_valid_in_fault_out_fake_credit or
                            S_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop or
                            S_err_state_out_Tail_flit_valid_in_fault_out_fault_info or
                            S_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in or
                            S_err_state_out_Tail_flit_not_valid_in_state_in_Idle or
                            S_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change or
                            S_err_state_out_Tail_flit_not_valid_in_not_fault_info or
                            S_err_state_out_Tail_flit_not_valid_in_not_fake_credit or
                            S_err_state_out_Tail_flit_not_write_fake_flit or

                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit or
                            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            S_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change or
                            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal or
                            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change or
                            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit or
                            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit or
                            S_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change or
                            S_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change or
                            S_err_state_out_Packet_drop_not_fault_info or
                            S_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit or
                            S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit or
                            S_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change or
                            S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change;

                            -- Functional checkers
L_FIFO_checkers_ORed  <=    L_err_empty_full or
                            L_err_empty_read_en or
                            L_err_full_write_en or
                            L_err_state_in_onehot or
                            L_err_read_pointer_in_onehot or
                            L_err_write_pointer_in_onehot or

                            -- Structural checkers
                            L_err_write_en_write_pointer or
                            L_err_not_write_en_write_pointer or
                            L_err_read_pointer_write_pointer_not_empty or
                            L_err_read_pointer_write_pointer_empty or
                            L_err_read_pointer_write_pointer_not_full or
                            L_err_read_pointer_write_pointer_full or
                            L_err_read_pointer_increment or
                            L_err_read_pointer_not_increment or
                            L_err_write_en or
                            L_err_not_write_en or
                            L_err_not_write_en1 or
                            L_err_not_write_en2 or
                            L_err_read_en_mismatch or
                            L_err_read_en_mismatch1 or

                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                            L_err_fake_credit_read_en_fake_credit_counter_in_increment or
                            L_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement or
                            L_err_not_fake_credit_read_en_fake_credit_counter_in_not_change or
                            L_err_fake_credit_not_read_en_fake_credit_counter_in_not_change or
                            L_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change or
                            L_err_fake_credit_read_en_credit_out or
                            L_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out or
                            L_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out or

                            -- Checkers for Packet Dropping FSM of FIFO
                            L_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit or
                            L_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change or
                            L_err_state_out_Idle_not_fault_out_not_fake_credit or
                            L_err_state_out_Idle_not_fault_out_not_fault_info or
                            L_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal or
                            L_err_state_out_Idle_fault_out_fake_credit or
                            L_err_state_out_Idle_fault_out_state_in_Packet_drop or
                            L_err_state_out_Idle_fault_out_fault_info or
                            L_err_state_out_Idle_fault_out_faulty_packet_in or
                            L_err_state_out_Idle_not_health_info or
                            L_err_state_out_Idle_not_write_fake_flit or

                            L_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit or
                            L_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit or
                            L_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit or
                            L_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info or
                            L_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            L_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit or
                            L_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop or
                            L_err_state_out_Header_flit_valid_in_fault_out_fault_info or
                            L_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in or
                            L_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change or
                            L_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            L_err_state_out_Header_flit_not_valid_in_not_fault_info or
                            L_err_state_out_Header_flit_not_valid_in_not_write_fake_flit or
                            L_err_state_out_Header_flit_or_Body_flit_not_fake_credit or

                            L_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change or
                            L_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit or
                            L_err_state_out_Body_flit_valid_in_not_fault_out_health_info or
                            L_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit or
                            L_err_state_out_Body_flit_valid_in_not_fault_out_fault_info or
                            L_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            L_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit or
                            L_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop or
                            L_err_state_out_Body_flit_valid_in_fault_out_fault_info or
                            L_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in or
                            L_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change or
                            L_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change or
                            L_err_state_out_Body_flit_not_valid_in_not_fault_info or
                            L_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info or
                            L_err_state_out_Body_flit_valid_in_fault_out_not_health_info or
                            L_err_state_out_Body_flit_valid_in_not_health_info or
                            L_err_state_out_Body_flit_not_fake_credit or
                            L_err_state_out_Body_flit_not_valid_in_not_write_fake_flit or

                            L_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit or
                            L_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit or
                            L_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info or
                            L_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            L_err_state_out_Tail_flit_valid_in_fault_out_fake_credit or
                            L_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop or
                            L_err_state_out_Tail_flit_valid_in_fault_out_fault_info or
                            L_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in or
                            L_err_state_out_Tail_flit_not_valid_in_state_in_Idle or
                            L_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change or
                            L_err_state_out_Tail_flit_not_valid_in_not_fault_info or
                            L_err_state_out_Tail_flit_not_valid_in_not_fake_credit or
                            L_err_state_out_Tail_flit_not_write_fake_flit or

                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit or
                            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change or
                            L_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change or
                            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal or
                            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change or
                            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit or
                            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit or
                            L_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change or
                            L_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change or
                            L_err_state_out_Packet_drop_not_fault_info or
                            L_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit or
                            L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit or
                            L_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change or
                            L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change;


-- Turn fault checkers
                            -- FIFO
N2E_turn_fault <=           N_FIFO_checkers_ORed or

                            -- LBDR
                            N_err_header_empty_Requests_FF_Requests_in or
                            N_err_tail_Requests_in_all_zero or
                            N_err_tail_empty_Requests_FF_Requests_in or
                            N_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            N_err_grants_onehot or
                            N_err_grants_mismatch or
                            N_err_header_tail_Requests_FF_Requests_in or
                            N_err_dst_addr_cur_addr_E1 or
                            N_err_dst_addr_cur_addr_not_E1 or
                            N_err_header_not_empty_Req_E_in or
                            N_err_header_not_empty_packet_drop_in or
                            N_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            N_err_header_empty_packet_drop_in_packet_drop_equal or
                            N_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            N_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            N_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            N_err_packet_drop_order or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            N_err_Requests_state_in_state_not_equal or
                            N_err_East_Req_E or
                            N_err_East_grant_E or
                            N_err_IDLE_Req_E or
                            N_err_IDLE_grant_E or
                            N_err_North_Req_E or
                            N_err_North_grant_E or
                            N_err_Local_Req_E or
                            N_err_Local_grant_E or
                            N_err_South_Req_E or
                            N_err_South_grant_E or
                            N_err_West_Req_E or
                            N_err_West_grant_E or
                            N_err_state_in_onehot or
                            N_err_no_request_grants or
                            N_err_request_no_grants or
                            N_err_no_Req_E_grant_E or
                            E_arbiter_out_err_Requests_state_in_state_not_equal or
                            E_err_IDLE_req_X_N or
                            E_err_North_req_X_N or
                            E_err_North_credit_not_zero_req_X_N_grant_N or
                            E_err_North_credit_zero_or_not_req_X_N_not_grant_N or
                            E_err_Local_req_X_N or
                            E_err_South_req_X_N or
                            E_err_West_req_X_N or
                            E_err_East_req_X_N or
                            E_arbiter_out_err_state_in_onehot or
                            E_arbiter_out_err_no_request_grants or
                            E_err_request_IDLE_state or
                            E_err_request_IDLE_not_Grants or
                            E_err_Grants_onehot_or_all_zero or
                            W_err_South_req_X_N or
                            W_err_West_req_X_N or
                            W_err_East_req_X_N or
                            err_grant_E_N_sig_not_empty_N_grant_E_N or
                            err_not_grant_E_N_sig_or_empty_N_not_grant_E_N or
                            err_grant_signals_not_empty_grant_E or
                            err_not_grant_signals_empty_not_grant_E or
                            err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal or
                            err_credit_in_E_credit_counter_E_out_increment or
                            err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change or
                            err_grant_E_credit_counter_E_out_decrement or
                            err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change or
                            err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal;

                            -- FIFO
N2W_turn_fault <=           N_FIFO_checkers_ORed or

                            -- LBDR
                            N_err_header_empty_Requests_FF_Requests_in or
                            N_err_tail_Requests_in_all_zero or
                            N_err_tail_empty_Requests_FF_Requests_in or
                            N_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            N_err_grants_onehot or
                            N_err_grants_mismatch or
                            N_err_header_tail_Requests_FF_Requests_in or
                            N_err_dst_addr_cur_addr_W1 or
                            N_err_dst_addr_cur_addr_not_W1 or
                            N_err_header_not_empty_Req_W_in or
                            N_err_header_not_empty_packet_drop_in or
                            N_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            N_err_header_empty_packet_drop_in_packet_drop_equal or
                            N_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            N_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            N_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            N_err_packet_drop_order or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            N_err_Requests_state_in_state_not_equal or
                            N_err_West_Req_W or
                            N_err_West_grant_W or
                            N_err_East_Req_W or
                            N_err_East_grant_W or
                            N_err_IDLE_Req_W or
                            N_err_IDLE_grant_W or
                            N_err_North_Req_W or
                            N_err_North_grant_W or
                            N_err_Local_Req_W or
                            N_err_Local_grant_W or
                            N_err_South_Req_W or
                            N_err_South_grant_W or
                            N_err_state_in_onehot or
                            N_err_no_request_grants or
                            N_err_request_no_grants or
                            N_err_no_Req_W_grant_W or
                            W_arbiter_out_err_Requests_state_in_state_not_equal or
                            W_err_IDLE_req_X_N or
                            W_err_North_req_X_N or
                            W_err_North_credit_not_zero_req_X_N_grant_N or
                            W_err_North_credit_zero_or_not_req_X_N_not_grant_N or
                            W_err_Local_req_X_N or
                            W_arbiter_out_err_state_in_onehot or
                            W_arbiter_out_err_no_request_grants or
                            W_err_request_IDLE_state or
                            W_err_request_IDLE_not_Grants or
                            W_err_Grants_onehot_or_all_zero or
                            err_grant_W_N_sig_not_empty_N_grant_W_N or
                            err_not_grant_W_N_sig_or_empty_N_not_grant_W_N or
                            err_grant_signals_not_empty_grant_W or
                            err_not_grant_signals_empty_not_grant_W or
                            err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal or
                            err_credit_in_W_credit_counter_W_out_increment or
                            err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change or
                            err_grant_W_credit_counter_W_out_decrement or
                            err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change or
                            err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal;

                            -- FIFO
E2N_turn_fault <=           E_FIFO_checkers_ORed or

                            -- LBDR
                            E_err_header_empty_Requests_FF_Requests_in or
                            E_err_tail_Requests_in_all_zero or
                            E_err_tail_empty_Requests_FF_Requests_in or
                            E_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            E_err_grants_onehot or
                            E_err_grants_mismatch or
                            E_err_header_tail_Requests_FF_Requests_in or
                            E_err_dst_addr_cur_addr_N1 or
                            E_err_dst_addr_cur_addr_not_N1 or
                            E_err_header_not_empty_Req_N_in or
                            E_err_header_not_empty_packet_drop_in or
                            E_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            E_err_header_empty_packet_drop_in_packet_drop_equal or
                            E_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            E_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            E_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            E_err_packet_drop_order or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            E_err_Requests_state_in_state_not_equal or
                            E_err_IDLE_Req_N or
                            E_err_IDLE_grant_N or
                            E_err_North_Req_N or
                            E_err_North_grant_N or
                            E_err_Local_Req_N or
                            E_err_Local_grant_N or
                            E_err_South_Req_N or
                            E_err_South_grant_N or
                            E_err_West_Req_N or
                            E_err_West_grant_N or
                            E_err_East_Req_N or
                            E_err_East_grant_N or
                            E_err_state_in_onehot or
                            E_err_no_request_grants or
                            E_err_request_no_grants or
                            E_err_no_Req_N_grant_N or
                            N_arbiter_out_err_Requests_state_in_state_not_equal or
                            N_err_East_req_X_E or
                            N_err_East_credit_not_zero_req_X_E_grant_E or
                            N_err_East_credit_zero_or_not_req_X_E_not_grant_E or
                            N_err_IDLE_req_X_E or
                            N_err_North_req_X_E or
                            N_err_Local_req_X_E or
                            N_err_South_req_X_E or
                            N_err_West_req_X_E or
                            N_arbiter_out_err_state_in_onehot or
                            N_arbiter_out_err_no_request_grants or
                            N_err_request_IDLE_state or
                            N_err_Grants_onehot_or_all_zero or
                            err_grant_N_E_sig_not_empty_E_grant_N_E or
                            err_not_grant_N_E_sig_or_empty_E_not_grant_N_E or
                            err_grant_signals_not_empty_grant_N or
                            err_not_grant_signals_empty_not_grant_N or
                            err_grants_valid_not_match or
                            err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal or
                            err_credit_in_N_credit_counter_N_out_increment or
                            err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change or
                            err_grant_N_credit_counter_N_out_decrement or
                            err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change or
                            err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal;

                            -- FIFO
E2S_turn_fault <=           E_FIFO_checkers_ORed or

                            -- LBDR
                            E_err_header_empty_Requests_FF_Requests_in or
                            E_err_tail_Requests_in_all_zero or
                            E_err_tail_empty_Requests_FF_Requests_in or
                            E_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            E_err_grants_onehot or
                            E_err_grants_mismatch or
                            E_err_header_tail_Requests_FF_Requests_in or
                            E_err_dst_addr_cur_addr_S1 or
                            E_err_dst_addr_cur_addr_not_S1 or
                            E_err_header_not_empty_Req_S_in or
                            E_err_header_not_empty_packet_drop_in or
                            E_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            E_err_header_empty_packet_drop_in_packet_drop_equal or
                            E_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            E_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            E_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            E_err_packet_drop_order or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            E_err_Requests_state_in_state_not_equal or
                            E_err_South_Req_S or
                            E_err_South_grant_S or
                            E_err_West_Req_S or
                            E_err_West_grant_S or
                            E_err_East_Req_S or
                            E_err_East_grant_S or
                            E_err_IDLE_Req_S or
                            E_err_IDLE_grant_S or
                            E_err_North_Req_S or
                            E_err_North_grant_S or
                            E_err_Local_Req_S or
                            E_err_Local_grant_S or
                            E_err_state_in_onehot or
                            E_err_no_request_grants or
                            E_err_request_no_grants or
                            E_err_no_Req_S_grant_S or
                            S_arbiter_out_err_Requests_state_in_state_not_equal or
                            S_err_East_req_X_E or
                            S_err_East_credit_not_zero_req_X_E_grant_E or
                            S_err_East_credit_zero_or_not_req_X_E_not_grant_E or
                            S_err_IDLE_req_X_E or
                            S_err_North_req_X_E or
                            S_err_Local_req_X_E or
                            S_err_South_req_X_E or
                            S_err_West_req_X_E or
                            S_arbiter_out_err_state_in_onehot or
                            S_arbiter_out_err_no_request_grants or
                            S_err_request_IDLE_state or
                            S_err_request_IDLE_not_Grants or
                            S_err_Grants_onehot_or_all_zero or
                            err_grant_S_E_sig_not_empty_E_grant_S_E or
                            err_not_grant_S_E_sig_or_empty_E_not_grant_S_E or
                            err_grant_signals_not_empty_grant_S or
                            err_not_grant_signals_empty_not_grant_S or
                            err_grants_valid_not_match or
                            err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal or
                            err_credit_in_S_credit_counter_S_out_increment or
                            err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change or
                            err_grant_S_credit_counter_S_out_decrement or
                            err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change or
                            err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal;

                            -- FIFO
W2N_turn_fault <=           W_FIFO_checkers_ORed or

                            -- LBDR
                            W_err_header_empty_Requests_FF_Requests_in or
                            W_err_tail_Requests_in_all_zero or
                            W_err_tail_empty_Requests_FF_Requests_in or
                            W_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            W_err_grants_onehot or
                            W_err_grants_mismatch or
                            W_err_header_tail_Requests_FF_Requests_in or
                            W_err_dst_addr_cur_addr_N1 or
                            W_err_dst_addr_cur_addr_not_N1 or
                            W_err_header_not_empty_Req_N_in or
                            W_err_header_not_empty_packet_drop_in or
                            W_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            W_err_header_empty_packet_drop_in_packet_drop_equal or
                            W_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            W_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            W_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            W_err_packet_drop_order or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            W_err_Requests_state_in_state_not_equal or
                            W_err_IDLE_Req_N or
                            W_err_IDLE_grant_N or
                            W_err_North_Req_N or
                            W_err_North_grant_N or
                            W_err_Local_Req_N or
                            W_err_Local_grant_N or
                            W_err_South_Req_N or
                            W_err_South_grant_N or
                            W_err_West_Req_N or
                            W_err_West_grant_N or
                            W_err_East_Req_N or
                            W_err_East_grant_N or
                            W_err_state_in_onehot or
                            W_err_no_request_grants or
                            W_err_request_no_grants or
                            W_err_no_Req_N_grant_N or
                            N_arbiter_out_err_Requests_state_in_state_not_equal or
                            N_err_West_req_X_W or
                            N_err_West_credit_not_zero_req_X_W_grant_W or
                            N_err_West_credit_zero_or_not_req_X_W_not_grant_W or
                            N_err_East_req_X_W or
                            N_err_IDLE_req_X_W or
                            N_err_North_req_X_W or
                            N_err_Local_req_X_W or
                            N_err_South_req_X_W or
                            N_arbiter_out_err_state_in_onehot or
                            N_arbiter_out_err_no_request_grants or
                            N_err_request_IDLE_state or
                            N_err_request_IDLE_not_Grants or
                            N_err_Grants_onehot_or_all_zero or
                            err_grant_N_W_sig_not_empty_W_grant_N_W or
                            err_not_grant_N_W_sig_or_empty_W_not_grant_N_W or
                            err_grant_signals_not_empty_grant_N or
                            err_not_grant_signals_empty_not_grant_N or
                            err_grants_valid_not_match or
                            err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal or
                            err_credit_in_N_credit_counter_N_out_increment or
                            err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change or
                            err_grant_N_credit_counter_N_out_decrement or
                            err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change or
                            err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal;

                            -- FIFO
W2S_turn_fault <=           W_FIFO_checkers_ORed or

                            -- LBDR
                            W_err_header_empty_Requests_FF_Requests_in or
                            W_err_tail_Requests_in_all_zero or
                            W_err_tail_empty_Requests_FF_Requests_in or
                            W_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            W_err_grants_onehot or
                            W_err_grants_mismatch or
                            W_err_header_tail_Requests_FF_Requests_in or
                            W_err_dst_addr_cur_addr_S1 or
                            W_err_dst_addr_cur_addr_not_S1 or
                            W_err_header_not_empty_Req_S_in or
                            W_err_header_not_empty_packet_drop_in or
                            W_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            W_err_header_empty_packet_drop_in_packet_drop_equal or
                            W_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            W_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            W_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            W_err_packet_drop_order or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            W_err_Requests_state_in_state_not_equal or
                            W_err_South_Req_S or
                            W_err_South_grant_S or
                            W_err_West_Req_S or
                            W_err_West_grant_S or
                            W_err_East_Req_S or
                            W_err_East_grant_S or
                            W_err_IDLE_Req_S or
                            W_err_IDLE_grant_S or
                            W_err_North_Req_S or
                            W_err_North_grant_S or
                            W_err_Local_Req_S or
                            W_err_Local_grant_S or
                            W_err_state_in_onehot or
                            W_err_no_request_grants or
                            W_err_request_no_grants or
                            W_err_no_Req_S_grant_S or
                            S_arbiter_out_err_Requests_state_in_state_not_equal or
                            S_err_West_req_X_W or
                            S_err_West_credit_not_zero_req_X_W_grant_W or
                            S_err_West_credit_zero_or_not_req_X_W_not_grant_W or
                            S_err_East_req_X_W or
                            S_err_IDLE_req_X_W or
                            S_err_North_req_X_W or
                            S_err_Local_req_X_W or
                            S_err_South_req_X_W or
                            S_arbiter_out_err_state_in_onehot or
                            S_arbiter_out_err_no_request_grants or
                            S_err_request_IDLE_state or
                            S_err_request_IDLE_not_Grants or
                            S_err_Grants_onehot_or_all_zero or
                            err_grant_S_W_sig_not_empty_W_grant_S_W or
                            err_not_grant_S_W_sig_or_empty_W_not_grant_S_W or
                            err_grant_signals_not_empty_grant_S or
                            err_not_grant_signals_empty_not_grant_S or
                            err_grants_valid_not_match or
                            err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal or
                            err_credit_in_S_credit_counter_S_out_increment or
                            err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change or
                            err_grant_S_credit_counter_S_out_decrement or
                            err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change or
                            err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal;

                            -- FIFO
S2E_turn_fault <=           S_FIFO_checkers_ORed or

                            -- LBDR
                            S_err_header_empty_Requests_FF_Requests_in or
                            S_err_tail_Requests_in_all_zero or
                            S_err_tail_empty_Requests_FF_Requests_in or
                            S_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            S_err_grants_onehot or
                            S_err_grants_mismatch or
                            S_err_header_tail_Requests_FF_Requests_in or
                            S_err_dst_addr_cur_addr_E1 or
                            S_err_dst_addr_cur_addr_not_E1 or
                            S_err_header_not_empty_Req_E_in or
                            S_err_header_not_empty_packet_drop_in or
                            S_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            S_err_header_empty_packet_drop_in_packet_drop_equal or
                            S_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            S_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            S_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            S_err_packet_drop_order or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            S_err_Requests_state_in_state_not_equal or
                            S_err_East_Req_E or
                            S_err_East_grant_E or
                            S_err_IDLE_Req_E or
                            S_err_IDLE_grant_E or
                            S_err_North_Req_E or
                            S_err_North_grant_E or
                            S_err_Local_Req_E or
                            S_err_Local_grant_E or
                            S_err_South_Req_E or
                            S_err_South_grant_E or
                            S_err_West_Req_E or
                            S_err_West_grant_E or
                            S_err_state_in_onehot or
                            S_err_no_request_grants or
                            S_err_request_no_grants or
                            S_err_no_Req_E_grant_E or
                            E_arbiter_out_err_Requests_state_in_state_not_equal or
                            E_err_South_req_X_S or
                            E_err_South_credit_not_zero_req_X_S_grant_S or
                            E_err_South_credit_zero_or_not_req_X_S_not_grant_S or
                            E_err_West_req_X_S or
                            E_err_East_req_X_S or
                            E_err_IDLE_req_X_S or
                            E_err_North_req_X_S or
                            E_err_Local_req_X_S or
                            E_arbiter_out_err_state_in_onehot or
                            E_arbiter_out_err_no_request_grants or
                            E_err_request_IDLE_state or
                            E_err_request_IDLE_not_Grants or
                            E_err_Grants_onehot_or_all_zero or
                            err_grant_E_S_sig_not_empty_S_grant_E_S or
                            err_not_grant_E_S_sig_or_empty_S_not_grant_E_S or
                            err_grant_signals_not_empty_grant_E or
                            err_not_grant_signals_empty_not_grant_E or
                            err_grants_valid_not_match or
                            err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal or
                            err_credit_in_E_credit_counter_E_out_increment or
                            err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change or
                            err_grant_E_credit_counter_E_out_decrement or
                            err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change or
                            err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal;

                            -- FIFO
S2W_turn_fault <=           S_FIFO_checkers_ORed or

                            -- LBDR
                            S_err_header_empty_Requests_FF_Requests_in or
                            S_err_tail_Requests_in_all_zero or
                            S_err_tail_empty_Requests_FF_Requests_in or
                            S_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            S_err_grants_onehot or
                            S_err_grants_mismatch or
                            S_err_header_tail_Requests_FF_Requests_in or
                            S_err_dst_addr_cur_addr_W1 or
                            S_err_dst_addr_cur_addr_not_W1 or
                            S_err_header_not_empty_Req_W_in or
                            S_err_header_not_empty_packet_drop_in or
                            S_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            S_err_header_empty_packet_drop_in_packet_drop_equal or
                            S_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            S_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            S_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            S_err_packet_drop_order or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            S_err_Requests_state_in_state_not_equal or
                            S_err_West_Req_W or
                            S_err_West_grant_W or
                            S_err_East_Req_W or
                            S_err_East_grant_W or
                            S_err_IDLE_Req_W or
                            S_err_IDLE_grant_W or
                            S_err_North_Req_W or
                            S_err_North_grant_W or
                            S_err_Local_Req_W or
                            S_err_Local_grant_W or
                            S_err_South_Req_W or
                            S_err_South_grant_W or
                            S_err_state_in_onehot or
                            S_err_no_request_grants or
                            S_err_request_no_grants or
                            S_err_no_Req_W_grant_W or
                            W_arbiter_out_err_Requests_state_in_state_not_equal or
                            W_err_South_req_X_S or
                            W_err_South_credit_not_zero_req_X_S_grant_S or
                            W_err_South_credit_zero_or_not_req_X_S_not_grant_S or
                            W_err_West_req_X_S or
                            W_err_East_req_X_S or
                            W_err_IDLE_req_X_S or
                            W_err_North_req_X_S or
                            W_err_Local_req_X_S or
                            W_arbiter_out_err_state_in_onehot or
                            W_arbiter_out_err_no_request_grants or
                            W_err_request_IDLE_state or
                            W_err_request_IDLE_not_Grants or
                            W_err_Grants_onehot_or_all_zero or
                            err_grant_W_S_sig_not_empty_S_grant_W_S or
                            err_not_grant_W_S_sig_or_empty_S_not_grant_W_S or
                            err_grant_signals_not_empty_grant_W or
                            err_not_grant_signals_empty_not_grant_W or
                            err_grants_valid_not_match or
                            err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal or
                            err_credit_in_W_credit_counter_W_out_increment or
                            err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change or
                            err_grant_W_credit_counter_W_out_decrement or
                            err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change or
                            err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal;

-- Path faults

                            -- FIFO
N2S_path_fault <=           N_FIFO_checkers_ORed or

                            -- LBDR
                            N_err_header_empty_Requests_FF_Requests_in or
                            N_err_tail_Requests_in_all_zero or
                            N_err_tail_empty_Requests_FF_Requests_in or
                            N_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            N_err_grants_onehot or
                            N_err_grants_mismatch or
                            N_err_header_tail_Requests_FF_Requests_in or
                            N_err_dst_addr_cur_addr_S1 or
                            N_err_dst_addr_cur_addr_not_S1 or
                            N_err_header_not_empty_Req_S_in or
                            N_err_header_not_empty_packet_drop_in or
                            N_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            N_err_header_empty_packet_drop_in_packet_drop_equal or
                            N_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            N_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            N_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            N_err_packet_drop_order or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            N_err_Requests_state_in_state_not_equal or
                            N_err_South_Req_S or
                            N_err_South_grant_S or
                            N_err_West_Req_S or
                            N_err_West_grant_S or
                            N_err_East_Req_S or
                            N_err_East_grant_S or
                            N_err_IDLE_Req_S or
                            N_err_IDLE_grant_S or
                            N_err_North_Req_S or
                            N_err_North_grant_S or
                            N_err_Local_Req_S or
                            N_err_Local_grant_S or
                            N_err_state_in_onehot or
                            N_err_no_request_grants or
                            N_err_request_no_grants or
                            N_err_no_Req_S_grant_S or
                            S_arbiter_out_err_Requests_state_in_state_not_equal or
                            S_err_IDLE_req_X_N or
                            S_err_North_req_X_N or
                            S_err_North_credit_not_zero_req_X_N_grant_N or
                            S_err_North_credit_zero_or_not_req_X_N_not_grant_N or
                            S_err_Local_req_X_N or
                            S_err_South_req_X_N or
                            S_err_West_req_X_N or
                            S_err_East_req_X_N or
                            S_arbiter_out_err_state_in_onehot or
                            S_arbiter_out_err_no_request_grants or
                            S_err_request_IDLE_state or
                            S_err_request_IDLE_not_Grants or
                            S_err_Grants_onehot_or_all_zero or
                            err_grant_S_N_sig_not_empty_N_grant_S_N or
                            err_not_grant_S_N_sig_or_empty_N_not_grant_S_N or
                            err_grant_signals_not_empty_grant_S or
                            err_not_grant_signals_empty_not_grant_S or
                            err_grants_valid_not_match or
                            err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal or
                            err_credit_in_S_credit_counter_S_out_increment or
                            err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change or
                            err_grant_S_credit_counter_S_out_decrement or
                            err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change or
                            err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal;

                            -- FIFO
S2N_path_fault <=           S_FIFO_checkers_ORed or

                            -- LBDR
                            S_err_header_empty_Requests_FF_Requests_in or
                            S_err_tail_Requests_in_all_zero or
                            S_err_tail_empty_Requests_FF_Requests_in or
                            S_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            S_err_grants_onehot or
                            S_err_grants_mismatch or
                            S_err_header_tail_Requests_FF_Requests_in or
                            S_err_dst_addr_cur_addr_N1 or
                            S_err_dst_addr_cur_addr_not_N1 or
                            S_err_header_not_empty_Req_N_in or
                            S_err_header_not_empty_packet_drop_in or
                            S_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            S_err_header_empty_packet_drop_in_packet_drop_equal or
                            S_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            S_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            S_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            S_err_packet_drop_order or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            S_err_Requests_state_in_state_not_equal or
                            S_err_IDLE_Req_N or
                            S_err_IDLE_grant_N or
                            S_err_North_Req_N or
                            S_err_North_grant_N or
                            S_err_Local_Req_N or
                            S_err_Local_grant_N or
                            S_err_South_Req_N or
                            S_err_South_grant_N or
                            S_err_West_Req_N or
                            S_err_West_grant_N or
                            S_err_East_Req_N or
                            S_err_East_grant_N or
                            S_err_state_in_onehot or
                            S_err_no_request_grants or
                            S_err_request_no_grants or
                            S_err_no_Req_N_grant_N or
                            N_arbiter_out_err_Requests_state_in_state_not_equal or
                            N_err_South_req_X_S or
                            N_err_South_credit_not_zero_req_X_S_grant_S or
                            N_err_South_credit_zero_or_not_req_X_S_not_grant_S or
                            N_err_West_req_X_S or
                            N_err_East_req_X_S or
                            N_err_IDLE_req_X_S or
                            N_err_North_req_X_S or
                            N_err_Local_req_X_S or
                            N_arbiter_out_err_state_in_onehot or
                            N_arbiter_out_err_no_request_grants or
                            N_err_request_IDLE_state or
                            N_err_request_IDLE_not_Grants or
                            N_err_Grants_onehot_or_all_zero or
                            err_grant_N_S_sig_not_empty_S_grant_N_S or
                            err_not_grant_N_S_sig_or_empty_S_not_grant_N_S or
                            err_grant_signals_not_empty_grant_N or
                            err_not_grant_signals_empty_not_grant_N or
                            err_grants_valid_not_match or
                            err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal or
                            err_credit_in_N_credit_counter_N_out_increment or
                            err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change or
                            err_grant_N_credit_counter_N_out_decrement or
                            err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change or
                            err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal;

                            -- FIFO
E2W_path_fault <=           E_FIFO_checkers_ORed or

                            -- LBDR
                            E_err_header_empty_Requests_FF_Requests_in or
                            E_err_tail_Requests_in_all_zero or
                            E_err_tail_empty_Requests_FF_Requests_in or
                            E_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            E_err_grants_onehot or
                            E_err_grants_mismatch or
                            E_err_header_tail_Requests_FF_Requests_in or
                            E_err_dst_addr_cur_addr_W1 or
                            E_err_dst_addr_cur_addr_not_W1 or
                            E_err_header_not_empty_Req_W_in or
                            E_err_header_not_empty_packet_drop_in or
                            E_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            E_err_header_empty_packet_drop_in_packet_drop_equal or
                            E_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            E_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            E_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            E_err_packet_drop_order or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            E_err_Requests_state_in_state_not_equal or
                            E_err_West_Req_W or
                            E_err_West_grant_W or
                            E_err_East_Req_W or
                            E_err_East_grant_W or
                            E_err_IDLE_Req_W or
                            E_err_IDLE_grant_W or
                            E_err_North_Req_W or
                            E_err_North_grant_W or
                            E_err_Local_Req_W or
                            E_err_Local_grant_W or
                            E_err_South_Req_W or
                            E_err_South_grant_W or
                            E_err_state_in_onehot or
                            E_err_no_request_grants or
                            E_err_request_no_grants or
                            E_err_no_Req_W_grant_W or
                            W_arbiter_out_err_Requests_state_in_state_not_equal or
                            W_err_East_req_X_E or
                            W_err_East_credit_not_zero_req_X_E_grant_E or
                            W_err_East_credit_zero_or_not_req_X_E_not_grant_E or
                            W_err_IDLE_req_X_E or
                            W_err_North_req_X_E or
                            W_err_Local_req_X_E or
                            W_err_South_req_X_E or
                            W_err_West_req_X_E or
                            W_arbiter_out_err_state_in_onehot or
                            W_arbiter_out_err_no_request_grants or
                            W_err_request_IDLE_state or
                            W_err_request_IDLE_not_Grants or
                            W_err_Grants_onehot_or_all_zero or
                            err_grant_W_E_sig_not_empty_E_grant_W_E or
                            err_not_grant_W_E_sig_or_empty_E_not_grant_W_E or
                            err_grant_signals_not_empty_grant_W or
                            err_not_grant_signals_empty_not_grant_W or
                            err_grants_valid_not_match or
                            err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal or
                            err_credit_in_W_credit_counter_W_out_increment or
                            err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change or
                            err_grant_W_credit_counter_W_out_decrement or
                            err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change or
                            err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal;

                            -- FIFO
W2E_path_fault <=           W_FIFO_checkers_ORed or

                            -- LBDR
                            W_err_header_empty_Requests_FF_Requests_in or
                            W_err_tail_Requests_in_all_zero or
                            W_err_tail_empty_Requests_FF_Requests_in or
                            W_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            W_err_grants_onehot or
                            W_err_grants_mismatch or
                            W_err_header_tail_Requests_FF_Requests_in or
                            W_err_dst_addr_cur_addr_E1 or
                            W_err_dst_addr_cur_addr_not_E1 or
                            W_err_header_not_empty_Req_E_in or
                            W_err_header_not_empty_packet_drop_in or
                            W_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            W_err_header_empty_packet_drop_in_packet_drop_equal or
                            W_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            W_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            W_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            W_err_packet_drop_order or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            W_err_Requests_state_in_state_not_equal or
                            W_err_East_Req_E or
                            W_err_East_grant_E or
                            W_err_IDLE_Req_E or
                            W_err_IDLE_grant_E or
                            W_err_North_Req_E or
                            W_err_North_grant_E or
                            W_err_Local_Req_E or
                            W_err_Local_grant_E or
                            W_err_South_Req_E or
                            W_err_South_grant_E or
                            W_err_West_Req_E or
                            W_err_West_grant_E or
                            W_err_state_in_onehot or
                            W_err_no_request_grants or
                            W_err_request_no_grants or
                            W_err_no_Req_E_grant_E or
                            E_arbiter_out_err_Requests_state_in_state_not_equal or
                            E_err_West_req_X_W or
                            E_err_West_credit_not_zero_req_X_W_grant_W or
                            E_err_West_credit_zero_or_not_req_X_W_not_grant_W or
                            E_err_East_req_X_W or
                            E_err_IDLE_req_X_W or
                            E_err_North_req_X_W or
                            E_err_Local_req_X_W or
                            E_err_South_req_X_W or
                            E_arbiter_out_err_state_in_onehot or
                            E_arbiter_out_err_no_request_grants or
                            E_err_request_IDLE_state or
                            E_err_request_IDLE_not_Grants or
                            E_err_Grants_onehot_or_all_zero or
                            err_grant_E_W_sig_not_empty_W_grant_E_W or
                            err_not_grant_E_W_sig_or_empty_W_not_grant_E_W or
                            err_grant_signals_not_empty_grant_E or
                            err_not_grant_signals_empty_not_grant_E or
                            err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal or
                            err_credit_in_E_credit_counter_E_out_increment or
                            err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change or
                            err_grant_E_credit_counter_E_out_decrement or
                            err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change or
                            err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal;

-- Paths/turns from/to Local

                            -- FIFO
L2N_fault <=                L_FIFO_checkers_ORed or

                            -- LBDR
                            L_err_header_empty_Requests_FF_Requests_in or
                            L_err_tail_Requests_in_all_zero or
                            L_err_tail_empty_Requests_FF_Requests_in or
                            L_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            L_err_grants_onehot or
                            L_err_grants_mismatch or
                            L_err_header_tail_Requests_FF_Requests_in or
                            L_err_dst_addr_cur_addr_N1 or
                            L_err_dst_addr_cur_addr_not_N1 or
                            L_err_header_not_empty_Req_N_in or
                            L_err_header_not_empty_packet_drop_in or
                            L_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            L_err_header_empty_packet_drop_in_packet_drop_equal or
                            L_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            L_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            L_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            L_err_packet_drop_order or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            L_err_Requests_state_in_state_not_equal or
                            L_err_IDLE_Req_N or
                            L_err_IDLE_grant_N or
                            L_err_North_Req_N or
                            L_err_North_grant_N or
                            L_err_Local_Req_N or
                            L_err_Local_grant_N or
                            L_err_South_Req_N or
                            L_err_South_grant_N or
                            L_err_West_Req_N or
                            L_err_West_grant_N or
                            L_err_East_Req_N or
                            L_err_East_grant_N or
                            L_err_state_in_onehot or
                            L_err_no_request_grants or
                            L_err_request_no_grants or
                            L_err_no_Req_N_grant_N or
                            N_arbiter_out_err_Requests_state_in_state_not_equal or
                            N_err_Local_req_X_L or
                            N_err_Local_credit_not_zero_req_X_L_grant_L or
                            N_err_Local_credit_zero_or_not_req_X_L_not_grant_L or
                            N_err_South_req_X_L or
                            N_err_West_req_X_L or
                            N_err_East_req_X_L or
                            N_err_IDLE_req_X_L or
                            N_err_North_req_X_L or
                            N_arbiter_out_err_state_in_onehot or
                            N_arbiter_out_err_no_request_grants or
                            N_err_request_IDLE_state or
                            N_err_request_IDLE_not_Grants or
                            N_err_Grants_onehot_or_all_zero or
                            err_grant_N_L_sig_not_empty_L_grant_N_L or
                            err_not_grant_N_L_sig_or_empty_L_not_grant_N_L or
                            err_grant_signals_not_empty_grant_N or
                            err_not_grant_signals_empty_not_grant_N or
                            err_grants_valid_not_match or
                            err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal or
                            err_credit_in_N_credit_counter_N_out_increment or
                            err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change or
                            err_grant_N_credit_counter_N_out_decrement or
                            err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change or
                            err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal;

                            -- FIFO
L2E_fault <=                L_FIFO_checkers_ORed or

                            -- LBDR
                            L_err_header_empty_Requests_FF_Requests_in or
                            L_err_tail_Requests_in_all_zero or
                            L_err_tail_empty_Requests_FF_Requests_in or
                            L_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            L_err_grants_onehot or
                            L_err_grants_mismatch or
                            L_err_header_tail_Requests_FF_Requests_in or
                            L_err_dst_addr_cur_addr_E1 or
                            L_err_dst_addr_cur_addr_not_E1 or
                            L_err_header_not_empty_Req_E_in or
                            L_err_header_not_empty_packet_drop_in or
                            L_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            L_err_header_empty_packet_drop_in_packet_drop_equal or
                            L_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            L_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            L_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            L_err_packet_drop_order or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            L_err_Requests_state_in_state_not_equal or
                            L_err_East_Req_E or
                            L_err_East_grant_E or
                            L_err_IDLE_Req_E or
                            L_err_IDLE_grant_E or
                            L_err_North_Req_E or
                            L_err_North_grant_E or
                            L_err_Local_Req_E or
                            L_err_Local_grant_E or
                            L_err_South_Req_E or
                            L_err_South_grant_E or
                            L_err_West_Req_E or
                            L_err_West_grant_E or
                            L_err_state_in_onehot or
                            L_err_no_request_grants or
                            L_err_request_no_grants or
                            L_err_no_Req_E_grant_E or
                            E_arbiter_out_err_Requests_state_in_state_not_equal or
                            E_err_Local_req_X_L or
                            E_err_Local_credit_not_zero_req_X_L_grant_L or
                            E_err_Local_credit_zero_or_not_req_X_L_not_grant_L or
                            E_err_South_req_X_L or
                            E_err_West_req_X_L or
                            E_err_East_req_X_L or
                            E_err_IDLE_req_X_L or
                            E_err_North_req_X_L or
                            E_arbiter_out_err_state_in_onehot or
                            E_arbiter_out_err_no_request_grants or
                            E_err_request_IDLE_state or
                            E_err_request_IDLE_not_Grants or
                            E_err_Grants_onehot_or_all_zero or
                            err_grant_E_L_sig_not_empty_L_grant_E_L or
                            err_not_grant_E_L_sig_or_empty_L_not_grant_E_L or
                            err_grant_signals_not_empty_grant_E or
                            err_not_grant_signals_empty_not_grant_E or
                            err_grants_valid_not_match or
                            err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal or
                            err_credit_in_E_credit_counter_E_out_increment or
                            err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change or
                            err_grant_E_credit_counter_E_out_decrement or
                            err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change or
                            err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal;

                            -- FIFO
L2W_fault <=                L_FIFO_checkers_ORed or

                            -- LBDR
                            L_err_header_empty_Requests_FF_Requests_in or
                            L_err_tail_Requests_in_all_zero or
                            L_err_tail_empty_Requests_FF_Requests_in or
                            L_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            L_err_grants_onehot or
                            L_err_grants_mismatch or
                            L_err_header_tail_Requests_FF_Requests_in or
                            L_err_dst_addr_cur_addr_W1 or
                            L_err_dst_addr_cur_addr_not_W1 or
                            L_err_header_not_empty_Req_W_in or
                            L_err_header_not_empty_packet_drop_in or
                            L_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            L_err_header_empty_packet_drop_in_packet_drop_equal or
                            L_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            L_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            L_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            L_err_packet_drop_order or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            L_err_Requests_state_in_state_not_equal or
                            L_err_West_Req_W or
                            L_err_West_grant_W or
                            L_err_East_Req_W or
                            L_err_East_grant_W or
                            L_err_IDLE_Req_W or
                            L_err_IDLE_grant_W or
                            L_err_North_Req_W or
                            L_err_North_grant_W or
                            L_err_Local_Req_W or
                            L_err_Local_grant_W or
                            L_err_South_Req_W or
                            L_err_South_grant_W or
                            L_err_state_in_onehot or
                            L_err_no_request_grants or
                            L_err_request_no_grants or
                            L_err_no_Req_W_grant_W or
                            W_arbiter_out_err_Requests_state_in_state_not_equal or
                            W_err_Local_req_X_L or
                            W_err_Local_credit_not_zero_req_X_L_grant_L or
                            W_err_Local_credit_zero_or_not_req_X_L_not_grant_L or
                            W_err_South_req_X_L or
                            W_err_West_req_X_L or
                            W_err_East_req_X_L or
                            W_err_IDLE_req_X_L or
                            W_err_North_req_X_L or
                            W_arbiter_out_err_state_in_onehot or
                            W_arbiter_out_err_no_request_grants or
                            W_err_request_IDLE_state or
                            W_err_request_IDLE_not_Grants or
                            W_err_Grants_onehot_or_all_zero or
                            err_grant_W_L_sig_not_empty_L_grant_W_L or
                            err_not_grant_W_L_sig_or_empty_L_not_grant_W_L or
                            err_grant_signals_not_empty_grant_W or
                            err_not_grant_signals_empty_not_grant_W or
                            err_grants_valid_not_match or
                            err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal or
                            err_credit_in_W_credit_counter_W_out_increment or
                            err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change or
                            err_grant_W_credit_counter_W_out_decrement or
                            err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change or
                            err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal;

                            -- FIFO
L2S_fault <=                L_FIFO_checkers_ORed or

                            -- LBDR
                            L_err_header_empty_Requests_FF_Requests_in or
                            L_err_tail_Requests_in_all_zero or
                            L_err_tail_empty_Requests_FF_Requests_in or
                            L_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            L_err_grants_onehot or
                            L_err_grants_mismatch or
                            L_err_header_tail_Requests_FF_Requests_in or
                            L_err_dst_addr_cur_addr_S1 or
                            L_err_dst_addr_cur_addr_not_S1 or
                            L_err_header_not_empty_Req_S_in or
                            L_err_header_not_empty_packet_drop_in or
                            L_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            L_err_header_empty_packet_drop_in_packet_drop_equal or
                            L_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            L_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            L_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            L_err_packet_drop_order or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            L_err_Requests_state_in_state_not_equal or
                            L_err_South_Req_S or
                            L_err_South_grant_S or
                            L_err_West_Req_S or
                            L_err_West_grant_S or
                            L_err_East_Req_S or
                            L_err_East_grant_S or
                            L_err_IDLE_Req_S or
                            L_err_IDLE_grant_S or
                            L_err_North_Req_S or
                            L_err_North_grant_S or
                            L_err_Local_Req_S or
                            L_err_Local_grant_S or
                            L_err_state_in_onehot or
                            L_err_no_request_grants or
                            L_err_request_no_grants or
                            L_err_no_Req_S_grant_S or
                            S_arbiter_out_err_Requests_state_in_state_not_equal or
                            S_err_Local_req_X_L or
                            S_err_Local_credit_not_zero_req_X_L_grant_L or
                            S_err_Local_credit_zero_or_not_req_X_L_not_grant_L or
                            S_err_South_req_X_L or
                            S_err_West_req_X_L or
                            S_err_East_req_X_L or
                            S_err_IDLE_req_X_L or
                            S_err_North_req_X_L or
                            S_arbiter_out_err_state_in_onehot or
                            S_arbiter_out_err_no_request_grants or
                            S_err_request_IDLE_state or
                            S_err_request_IDLE_not_Grants or
                            S_err_Grants_onehot_or_all_zero or
                            err_grant_S_L_sig_not_empty_L_grant_S_L or
                            err_not_grant_S_L_sig_or_empty_L_not_grant_S_L or
                            err_grant_signals_not_empty_grant_S or
                            err_not_grant_signals_empty_not_grant_S or
                            err_grants_valid_not_match or
                            err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal or
                            err_credit_in_S_credit_counter_S_out_increment or
                            err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change or
                            err_grant_S_credit_counter_S_out_decrement or
                            err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change or
                            err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal;

                            -- FIFO
N2L_fault <=                N_FIFO_checkers_ORed or

                            -- LBDR
                            N_err_header_empty_Requests_FF_Requests_in or
                            N_err_tail_Requests_in_all_zero or
                            N_err_tail_empty_Requests_FF_Requests_in or
                            N_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            N_err_grants_onehot or
                            N_err_grants_mismatch or
                            N_err_header_tail_Requests_FF_Requests_in or
                            N_err_dst_addr_cur_addr_not_Req_L_in or
                            N_err_dst_addr_cur_addr_Req_L_in or
                            N_err_header_not_empty_packet_drop_in or
                            N_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            N_err_header_empty_packet_drop_in_packet_drop_equal or
                            N_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            N_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            N_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            N_err_packet_drop_order or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            N_err_Requests_state_in_state_not_equal or
                            N_err_Local_Req_L or
                            N_err_Local_grant_L or
                            N_err_South_Req_L or
                            N_err_South_grant_L or
                            N_err_West_Req_L or
                            N_err_West_grant_L or
                            N_err_East_Req_L or
                            N_err_East_grant_L or
                            N_err_IDLE_Req_L or
                            N_err_IDLE_grant_L or
                            N_err_North_Req_L or
                            N_err_North_grant_L or
                            N_err_state_in_onehot or
                            N_err_no_request_grants or
                            N_err_request_no_grants or
                            N_err_no_Req_L_grant_L or
                            L_arbiter_out_err_Requests_state_in_state_not_equal or
                            L_err_IDLE_req_X_N or
                            L_err_North_req_X_N or
                            L_err_North_credit_not_zero_req_X_N_grant_N or
                            L_err_North_credit_zero_or_not_req_X_N_not_grant_N or
                            L_err_Local_req_X_N or
                            L_err_South_req_X_N or
                            L_err_West_req_X_N or
                            L_err_East_req_X_N or
                            L_arbiter_out_err_state_in_onehot or
                            L_arbiter_out_err_no_request_grants or
                            L_err_request_IDLE_state or
                            L_err_request_IDLE_not_Grants or
                            L_err_Grants_onehot_or_all_zero or
                            err_grant_L_N_sig_not_empty_N_grant_L_N or
                            err_not_grant_L_N_sig_or_empty_N_not_grant_L_N or
                            err_grant_signals_not_empty_grant_L or
                            err_not_grant_signals_empty_not_grant_L or
                            err_grants_valid_not_match or
                            err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal or
                            err_credit_in_L_credit_counter_L_out_increment or
                            err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change or
                            err_grant_L_credit_counter_L_out_decrement or
                            err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change or
                            err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal;

                            -- FIFO
E2L_fault <=                E_FIFO_checkers_ORed or

                            -- LBDR
                            E_err_header_empty_Requests_FF_Requests_in or
                            E_err_tail_Requests_in_all_zero or
                            E_err_tail_empty_Requests_FF_Requests_in or
                            E_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            E_err_grants_onehot or
                            E_err_grants_mismatch or
                            E_err_header_tail_Requests_FF_Requests_in or
                            E_err_dst_addr_cur_addr_not_Req_L_in or
                            E_err_dst_addr_cur_addr_Req_L_in or
                            E_err_header_not_empty_packet_drop_in or
                            E_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            E_err_header_empty_packet_drop_in_packet_drop_equal or
                            E_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            E_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            E_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            E_err_packet_drop_order or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            E_err_Requests_state_in_state_not_equal or
                            E_err_Local_Req_L or
                            E_err_Local_grant_L or
                            E_err_South_Req_L or
                            E_err_South_grant_L or
                            E_err_West_Req_L or
                            E_err_West_grant_L or
                            E_err_East_Req_L or
                            E_err_East_grant_L or
                            E_err_IDLE_Req_L or
                            E_err_IDLE_grant_L or
                            E_err_North_Req_L or
                            E_err_North_grant_L or
                            E_err_state_in_onehot or
                            E_err_no_request_grants or
                            E_err_request_no_grants or
                            E_err_no_Req_L_grant_L or
                            L_arbiter_out_err_Requests_state_in_state_not_equal or
                            L_err_East_req_X_E or
                            L_err_East_credit_not_zero_req_X_E_grant_E or
                            L_err_East_credit_zero_or_not_req_X_E_not_grant_E or
                            L_err_IDLE_req_X_E or
                            L_err_North_req_X_E or
                            L_err_Local_req_X_E or
                            L_err_South_req_X_E or
                            L_err_West_req_X_E or
                            L_arbiter_out_err_state_in_onehot or
                            L_arbiter_out_err_no_request_grants or
                            L_err_request_IDLE_state or
                            L_err_request_IDLE_not_Grants or
                            L_err_Grants_onehot_or_all_zero or
                            err_grant_L_E_sig_not_empty_E_grant_L_E or
                            err_not_grant_L_E_sig_or_empty_E_not_grant_L_E or
                            err_grant_signals_not_empty_grant_L or
                            err_not_grant_signals_empty_not_grant_L or
                            err_grants_valid_not_match or
                            err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal or
                            err_credit_in_L_credit_counter_L_out_increment or
                            err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change or
                            err_grant_L_credit_counter_L_out_decrement or
                            err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change or
                            err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal;

                            -- FIFO
W2L_fault <=                W_FIFO_checkers_ORed or

                            -- LBDR
                            W_err_header_empty_Requests_FF_Requests_in or
                            W_err_tail_Requests_in_all_zero or
                            W_err_tail_empty_Requests_FF_Requests_in or
                            W_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            W_err_grants_onehot or
                            W_err_grants_mismatch or
                            W_err_header_tail_Requests_FF_Requests_in or
                            W_err_dst_addr_cur_addr_not_Req_L_in or
                            W_err_dst_addr_cur_addr_Req_L_in or
                            W_err_header_not_empty_packet_drop_in or
                            W_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            W_err_header_empty_packet_drop_in_packet_drop_equal or
                            W_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            W_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            W_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            W_err_packet_drop_order or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            W_err_Requests_state_in_state_not_equal or
                            W_err_Local_Req_L or
                            W_err_Local_grant_L or
                            W_err_South_Req_L or
                            W_err_South_grant_L or
                            W_err_West_Req_L or
                            W_err_West_grant_L or
                            W_err_East_Req_L or
                            W_err_East_grant_L or
                            W_err_IDLE_Req_L or
                            W_err_IDLE_grant_L or
                            W_err_North_Req_L or
                            W_err_North_grant_L or
                            W_err_state_in_onehot or
                            W_err_no_request_grants or
                            W_err_request_no_grants or
                            W_err_no_Req_L_grant_L or
                            L_arbiter_out_err_Requests_state_in_state_not_equal or
                            L_err_West_req_X_W or
                            L_err_West_credit_not_zero_req_X_W_grant_W or
                            L_err_West_credit_zero_or_not_req_X_W_not_grant_W or
                            L_err_East_req_X_W or
                            L_err_IDLE_req_X_W or
                            L_err_North_req_X_W or
                            L_err_Local_req_X_W or
                            L_err_South_req_X_W or
                            L_arbiter_out_err_state_in_onehot or
                            L_arbiter_out_err_no_request_grants or
                            L_err_request_IDLE_state or
                            L_err_request_IDLE_not_Grants or
                            L_err_Grants_onehot_or_all_zero or
                            err_grant_L_W_sig_not_empty_W_grant_L_W or
                            err_not_grant_L_W_sig_or_empty_W_not_grant_L_W or
                            err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal or
                            err_credit_in_L_credit_counter_L_out_increment or
                            err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change or
                            err_grant_L_credit_counter_L_out_decrement or
                            err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change or
                            err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal;

                            -- FIFO
S2L_fault <=                S_FIFO_checkers_ORed or

                            -- LBDR
                            S_err_header_empty_Requests_FF_Requests_in or
                            S_err_tail_Requests_in_all_zero or
                            S_err_tail_empty_Requests_FF_Requests_in or
                            S_err_tail_not_empty_not_grants_Requests_FF_Requests_in or
                            S_err_grants_onehot or
                            S_err_grants_mismatch or
                            S_err_header_tail_Requests_FF_Requests_in or
                            S_err_dst_addr_cur_addr_not_Req_L_in or
                            S_err_dst_addr_cur_addr_Req_L_in or
                            S_err_header_not_empty_packet_drop_in or
                            S_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal or
                            S_err_header_empty_packet_drop_in_packet_drop_equal or
                            S_err_tail_not_empty_packet_drop_not_packet_drop_in or
                            S_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal or
                            S_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal or
                            S_err_packet_drop_order or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal or
                            S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in or
                            S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal or
                            S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal or
                            S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal or

                            -- Allocator
                            S_err_Requests_state_in_state_not_equal or
                            S_err_Local_Req_L or
                            S_err_Local_grant_L or
                            S_err_South_Req_L or
                            S_err_South_grant_L or
                            S_err_West_Req_L or
                            S_err_West_grant_L or
                            S_err_East_Req_L or
                            S_err_East_grant_L or
                            S_err_IDLE_Req_L or
                            S_err_IDLE_grant_L or
                            S_err_North_Req_L or
                            S_err_North_grant_L or
                            S_err_state_in_onehot or
                            S_err_no_request_grants or
                            S_err_request_no_grants or
                            S_err_no_Req_L_grant_L or
                            L_arbiter_out_err_Requests_state_in_state_not_equal or
                            L_err_South_req_X_S or
                            L_err_South_credit_not_zero_req_X_S_grant_S or
                            L_err_South_credit_zero_or_not_req_X_S_not_grant_S or
                            L_err_West_req_X_S or
                            L_err_East_req_X_S or
                            L_err_IDLE_req_X_S or
                            L_err_North_req_X_S or
                            L_err_Local_req_X_S or
                            L_arbiter_out_err_state_in_onehot or
                            L_arbiter_out_err_no_request_grants or
                            L_err_request_IDLE_state or
                            L_err_request_IDLE_not_Grants or
                            L_err_Grants_onehot_or_all_zero or
                            err_grant_L_S_sig_not_empty_S_grant_L_S or
                            err_not_grant_L_S_sig_or_empty_S_not_grant_L_S or
                            err_grant_signals_not_empty_grant_L or
                            err_not_grant_signals_empty_not_grant_L or
                            err_grants_valid_not_match or
                            err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal or
                            err_credit_in_L_credit_counter_L_out_increment or
                            err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change or
                            err_grant_L_credit_counter_L_out_decrement or
                            err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change or
                            err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal;


Faulty_N_out <= sig_Faulty_N_out;
Faulty_E_out <= sig_Faulty_E_out;
Faulty_W_out <= sig_Faulty_W_out;
Faulty_S_out <= sig_Faulty_S_out;


-- all the counter_threshold modules
CT_N:  counter_threshold_classifier  generic map(counter_depth => counter_depth, healthy_counter_threshold => healthy_counter_threshold, faulty_counter_threshold => faulty_counter_threshold)
    port map(reset => reset, clk => clk, faulty_packet => faulty_packet_N, Healthy_packet => healthy_packet_N,
             Healthy => healthy_link_N, intermittent=> intermittent_link_N, Faulty => sig_Faulty_N_out);

CT_E:  counter_threshold_classifier  generic map(counter_depth => counter_depth, healthy_counter_threshold => healthy_counter_threshold, faulty_counter_threshold => faulty_counter_threshold)
    port map(reset => reset, clk => clk, faulty_packet => faulty_packet_E, Healthy_packet => healthy_packet_E,
             Healthy => healthy_link_E, intermittent=> intermittent_link_E, Faulty => sig_Faulty_E_out);

CT_W:  counter_threshold_classifier  generic map(counter_depth => counter_depth, healthy_counter_threshold => healthy_counter_threshold, faulty_counter_threshold => faulty_counter_threshold)
    port map(reset => reset, clk => clk, faulty_packet => faulty_packet_W, Healthy_packet => healthy_packet_W,
             Healthy => healthy_link_W, intermittent=> intermittent_link_W, Faulty => sig_Faulty_W_out);

CT_S:  counter_threshold_classifier  generic map(counter_depth => counter_depth, healthy_counter_threshold => healthy_counter_threshold, faulty_counter_threshold => faulty_counter_threshold)
    port map(reset => reset, clk => clk, faulty_packet => faulty_packet_S, Healthy_packet => healthy_packet_S,
             Healthy => healthy_link_S, intermittent=> intermittent_link_S, Faulty => sig_Faulty_S_out);

CT_L:  counter_threshold_classifier  generic map(counter_depth => counter_depth, healthy_counter_threshold => healthy_counter_threshold, faulty_counter_threshold => faulty_counter_threshold)
    port map(reset => reset, clk => clk, faulty_packet => faulty_packet_L, Healthy_packet => healthy_packet_L,
             Healthy => healthy_link_L, intermittent=> intermittent_link_L, Faulty => faulty_link_L);

-- All the FIFOs
FIFO_N: FIFO_credit_based
    generic map ( DATA_WIDTH => DATA_WIDTH)
    port map ( reset => reset, clk => clk, RX => RX_N, valid_in => valid_in_N,
            read_en_N => packet_drop_order_N, read_en_E =>Grant_EN, read_en_W =>Grant_WN, read_en_S =>Grant_SN, read_en_L =>Grant_LN,
            credit_out => credit_out_N, empty_out => empty_N, Data_out => FIFO_D_out_N, fault_info=> faulty_packet_N, health_info=>healthy_packet_N,

            -- Checker outputs
                                                            -- Functional checkers
                                                            err_empty_full => N_err_empty_full,
                                                            err_empty_read_en => N_err_empty_read_en,
                                                            err_full_write_en => N_err_full_write_en,
                                                            err_state_in_onehot => N_err_state_in_onehot,
                                                            err_read_pointer_in_onehot => N_err_read_pointer_in_onehot,
                                                            err_write_pointer_in_onehot => N_err_write_pointer_in_onehot,

                                                            -- Structural checkers
                                                            err_write_en_write_pointer => N_err_write_en_write_pointer,
                                                            err_not_write_en_write_pointer => N_err_not_write_en_write_pointer,
                                                            err_read_pointer_write_pointer_not_empty => N_err_read_pointer_write_pointer_not_empty,
                                                            err_read_pointer_write_pointer_empty => N_err_read_pointer_write_pointer_empty,
                                                            err_read_pointer_write_pointer_not_full => N_err_read_pointer_write_pointer_not_full,
                                                            err_read_pointer_write_pointer_full => N_err_read_pointer_write_pointer_full,
                                                            err_read_pointer_increment => N_err_read_pointer_increment,
                                                            err_read_pointer_not_increment => N_err_read_pointer_not_increment,
                                                            err_write_en => N_err_write_en,
                                                            err_not_write_en => N_err_not_write_en,
                                                            err_not_write_en1 => N_err_not_write_en1,
                                                            err_not_write_en2 => N_err_not_write_en2,
                                                            err_read_en_mismatch => N_err_read_en_mismatch,
                                                            err_read_en_mismatch1 => N_err_read_en_mismatch1,

                                                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                                                            err_fake_credit_read_en_fake_credit_counter_in_increment => N_err_fake_credit_read_en_fake_credit_counter_in_increment,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement => N_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
                                                            err_not_fake_credit_read_en_fake_credit_counter_in_not_change => N_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
                                                            err_fake_credit_not_read_en_fake_credit_counter_in_not_change => N_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change => N_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
                                                            err_fake_credit_read_en_credit_out => N_err_fake_credit_read_en_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out => N_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out => N_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

                                                            -- Checkers for Packet Dropping FSM of FIFO
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit => N_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_not_change => N_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
                                                            err_state_out_Idle_not_fault_out_not_fake_credit => N_err_state_out_Idle_not_fault_out_not_fake_credit,
                                                            err_state_out_Idle_not_fault_out_not_fault_info => N_err_state_out_Idle_not_fault_out_not_fault_info,
                                                            err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal => N_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Idle_fault_out_fake_credit => N_err_state_out_Idle_fault_out_fake_credit,
                                                            err_state_out_Idle_fault_out_state_in_Packet_drop => N_err_state_out_Idle_fault_out_state_in_Packet_drop,
                                                            err_state_out_Idle_fault_out_fault_info => N_err_state_out_Idle_fault_out_fault_info,
                                                            err_state_out_Idle_fault_out_faulty_packet_in => N_err_state_out_Idle_fault_out_faulty_packet_in,
                                                            err_state_out_Idle_not_health_info => N_err_state_out_Idle_not_health_info,
                                                            err_state_out_Idle_not_write_fake_flit => N_err_state_out_Idle_not_write_fake_flit,

                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit => N_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit => N_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit => N_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info => N_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => N_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_valid_in_fault_out_write_fake_flit => N_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop => N_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Header_flit_valid_in_fault_out_fault_info => N_err_state_out_Header_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in => N_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change => N_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => N_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_not_fault_info => N_err_state_out_Header_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Header_flit_not_valid_in_not_write_fake_flit => N_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Header_flit_or_Body_flit_not_fake_credit => N_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change => N_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit => N_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_health_info => N_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit => N_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_fault_info => N_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => N_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_valid_in_fault_out_write_fake_flit => N_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop => N_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Body_flit_valid_in_fault_out_fault_info => N_err_state_out_Body_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in => N_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change => N_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => N_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_not_fault_info => N_err_state_out_Body_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info => N_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_not_health_info => N_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
                                                            err_state_out_Body_flit_valid_in_not_health_info => N_err_state_out_Body_flit_valid_in_not_health_info,
                                                            err_state_out_Body_flit_not_fake_credit => N_err_state_out_Body_flit_not_fake_credit,
                                                            err_state_out_Body_flit_not_valid_in_not_write_fake_flit => N_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

                                                            err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit => N_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit => N_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info => N_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => N_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fake_credit => N_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop => N_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fault_info => N_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in => N_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Tail_flit_not_valid_in_state_in_Idle => N_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
                                                            err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change => N_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
                                                            err_state_out_Tail_flit_not_valid_in_not_fault_info => N_err_state_out_Tail_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Tail_flit_not_valid_in_not_fake_credit => N_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
                                                            err_state_out_Tail_flit_not_write_fake_flit => N_err_state_out_Tail_flit_not_write_fake_flit,

                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change => N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change => N_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal => N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change => N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit => N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit => N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change => N_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change => N_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_not_fault_info => N_err_state_out_Packet_drop_not_fault_info,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit => N_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit => N_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit => N_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change => N_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change
            );

FIFO_E: FIFO_credit_based
    generic map ( DATA_WIDTH => DATA_WIDTH)
    port map ( reset => reset, clk => clk, RX => RX_E, valid_in => valid_in_E,
            read_en_N => Grant_NE, read_en_E =>packet_drop_order_E, read_en_W =>Grant_WE, read_en_S =>Grant_SE, read_en_L =>Grant_LE,
            credit_out => credit_out_E, empty_out => empty_E, Data_out => FIFO_D_out_E, fault_info=> faulty_packet_E, health_info=>healthy_packet_E,

                                                            -- Functional checkers
                                                            err_empty_full => E_err_empty_full,
                                                            err_empty_read_en => E_err_empty_read_en,
                                                            err_full_write_en => E_err_full_write_en,
                                                            err_state_in_onehot => E_err_state_in_onehot,
                                                            err_read_pointer_in_onehot => E_err_read_pointer_in_onehot,
                                                            err_write_pointer_in_onehot => E_err_write_pointer_in_onehot,

                                                            -- Structural checkers
                                                            err_write_en_write_pointer => E_err_write_en_write_pointer,
                                                            err_not_write_en_write_pointer => E_err_not_write_en_write_pointer,
                                                            err_read_pointer_write_pointer_not_empty => E_err_read_pointer_write_pointer_not_empty,
                                                            err_read_pointer_write_pointer_empty => E_err_read_pointer_write_pointer_empty,
                                                            err_read_pointer_write_pointer_not_full => E_err_read_pointer_write_pointer_not_full,
                                                            err_read_pointer_write_pointer_full => E_err_read_pointer_write_pointer_full,
                                                            err_read_pointer_increment => E_err_read_pointer_increment,
                                                            err_read_pointer_not_increment => E_err_read_pointer_not_increment,
                                                            err_write_en => E_err_write_en,
                                                            err_not_write_en => E_err_not_write_en,
                                                            err_not_write_en1 => E_err_not_write_en1,
                                                            err_not_write_en2 => E_err_not_write_en2,
                                                            err_read_en_mismatch => E_err_read_en_mismatch,
                                                            err_read_en_mismatch1 => E_err_read_en_mismatch1,

                                                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                                                            err_fake_credit_read_en_fake_credit_counter_in_increment => E_err_fake_credit_read_en_fake_credit_counter_in_increment,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement => E_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
                                                            err_not_fake_credit_read_en_fake_credit_counter_in_not_change => E_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
                                                            err_fake_credit_not_read_en_fake_credit_counter_in_not_change => E_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change => E_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
                                                            err_fake_credit_read_en_credit_out => E_err_fake_credit_read_en_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out => E_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out => E_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

                                                            -- Checkers for Packet Dropping FSM of FIFO
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit => E_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_not_change => E_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
                                                            err_state_out_Idle_not_fault_out_not_fake_credit => E_err_state_out_Idle_not_fault_out_not_fake_credit,
                                                            err_state_out_Idle_not_fault_out_not_fault_info => E_err_state_out_Idle_not_fault_out_not_fault_info,
                                                            err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal => E_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Idle_fault_out_fake_credit => E_err_state_out_Idle_fault_out_fake_credit,
                                                            err_state_out_Idle_fault_out_state_in_Packet_drop => E_err_state_out_Idle_fault_out_state_in_Packet_drop,
                                                            err_state_out_Idle_fault_out_fault_info => E_err_state_out_Idle_fault_out_fault_info,
                                                            err_state_out_Idle_fault_out_faulty_packet_in => E_err_state_out_Idle_fault_out_faulty_packet_in,
                                                            err_state_out_Idle_not_health_info => E_err_state_out_Idle_not_health_info,
                                                            err_state_out_Idle_not_write_fake_flit => E_err_state_out_Idle_not_write_fake_flit,

                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit => E_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit => E_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit => E_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info => E_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => E_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_valid_in_fault_out_write_fake_flit => E_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop => E_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Header_flit_valid_in_fault_out_fault_info => E_err_state_out_Header_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in => E_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change => E_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => E_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_not_fault_info => E_err_state_out_Header_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Header_flit_not_valid_in_not_write_fake_flit => E_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Header_flit_or_Body_flit_not_fake_credit => E_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change => E_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit => E_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_health_info => E_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit => E_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_fault_info => E_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => E_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_valid_in_fault_out_write_fake_flit => E_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop => E_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Body_flit_valid_in_fault_out_fault_info => E_err_state_out_Body_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in => E_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change => E_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => E_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_not_fault_info => E_err_state_out_Body_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info => E_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_not_health_info => E_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
                                                            err_state_out_Body_flit_valid_in_not_health_info => E_err_state_out_Body_flit_valid_in_not_health_info,
                                                            err_state_out_Body_flit_not_fake_credit => E_err_state_out_Body_flit_not_fake_credit,
                                                            err_state_out_Body_flit_not_valid_in_not_write_fake_flit => E_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

                                                            err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit => E_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit => E_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info => E_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => E_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fake_credit => E_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop => E_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fault_info => E_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in => E_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Tail_flit_not_valid_in_state_in_Idle => E_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
                                                            err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change => E_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
                                                            err_state_out_Tail_flit_not_valid_in_not_fault_info => E_err_state_out_Tail_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Tail_flit_not_valid_in_not_fake_credit => E_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
                                                            err_state_out_Tail_flit_not_write_fake_flit => E_err_state_out_Tail_flit_not_write_fake_flit,

                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change => E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change => E_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal => E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change => E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit => E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit => E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change => E_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change => E_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_not_fault_info => E_err_state_out_Packet_drop_not_fault_info,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit => E_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit => E_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit => E_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change => E_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change
            );

FIFO_W: FIFO_credit_based
    generic map ( DATA_WIDTH => DATA_WIDTH)
    port map ( reset => reset, clk => clk, RX => RX_W, valid_in => valid_in_W,
            read_en_N => Grant_NW, read_en_E =>Grant_EW, read_en_W =>packet_drop_order_W, read_en_S =>Grant_SW, read_en_L =>Grant_LW,
            credit_out => credit_out_W, empty_out => empty_W, Data_out => FIFO_D_out_W, fault_info=> faulty_packet_W, health_info=>healthy_packet_W,

                                                            -- Functional checkers
                                                            err_empty_full => W_err_empty_full,
                                                            err_empty_read_en => W_err_empty_read_en,
                                                            err_full_write_en => W_err_full_write_en,
                                                            err_state_in_onehot => W_err_state_in_onehot,
                                                            err_read_pointer_in_onehot => W_err_read_pointer_in_onehot,
                                                            err_write_pointer_in_onehot => W_err_write_pointer_in_onehot,

                                                            -- Structural checkers
                                                            err_write_en_write_pointer => W_err_write_en_write_pointer,
                                                            err_not_write_en_write_pointer => W_err_not_write_en_write_pointer,
                                                            err_read_pointer_write_pointer_not_empty => W_err_read_pointer_write_pointer_not_empty,
                                                            err_read_pointer_write_pointer_empty => W_err_read_pointer_write_pointer_empty,
                                                            err_read_pointer_write_pointer_not_full => W_err_read_pointer_write_pointer_not_full,
                                                            err_read_pointer_write_pointer_full => W_err_read_pointer_write_pointer_full,
                                                            err_read_pointer_increment => W_err_read_pointer_increment,
                                                            err_read_pointer_not_increment => W_err_read_pointer_not_increment,
                                                            err_write_en => W_err_write_en,
                                                            err_not_write_en => W_err_not_write_en,
                                                            err_not_write_en1 => W_err_not_write_en1,
                                                            err_not_write_en2 => W_err_not_write_en2,
                                                            err_read_en_mismatch => W_err_read_en_mismatch,
                                                            err_read_en_mismatch1 => W_err_read_en_mismatch1,

                                                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                                                            err_fake_credit_read_en_fake_credit_counter_in_increment => W_err_fake_credit_read_en_fake_credit_counter_in_increment,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement => W_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
                                                            err_not_fake_credit_read_en_fake_credit_counter_in_not_change => W_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
                                                            err_fake_credit_not_read_en_fake_credit_counter_in_not_change => W_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change => W_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
                                                            err_fake_credit_read_en_credit_out => W_err_fake_credit_read_en_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out => W_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out => W_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

                                                            -- Checkers for Packet Dropping FSM of FIFO
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit => W_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_not_change => W_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
                                                            err_state_out_Idle_not_fault_out_not_fake_credit => W_err_state_out_Idle_not_fault_out_not_fake_credit,
                                                            err_state_out_Idle_not_fault_out_not_fault_info => W_err_state_out_Idle_not_fault_out_not_fault_info,
                                                            err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal => W_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Idle_fault_out_fake_credit => W_err_state_out_Idle_fault_out_fake_credit,
                                                            err_state_out_Idle_fault_out_state_in_Packet_drop => W_err_state_out_Idle_fault_out_state_in_Packet_drop,
                                                            err_state_out_Idle_fault_out_fault_info => W_err_state_out_Idle_fault_out_fault_info,
                                                            err_state_out_Idle_fault_out_faulty_packet_in => W_err_state_out_Idle_fault_out_faulty_packet_in,
                                                            err_state_out_Idle_not_health_info => W_err_state_out_Idle_not_health_info,
                                                            err_state_out_Idle_not_write_fake_flit => W_err_state_out_Idle_not_write_fake_flit,

                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit => W_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit => W_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit => W_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info => W_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => W_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_valid_in_fault_out_write_fake_flit => W_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop => W_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Header_flit_valid_in_fault_out_fault_info => W_err_state_out_Header_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in => W_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change => W_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => W_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_not_fault_info => W_err_state_out_Header_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Header_flit_not_valid_in_not_write_fake_flit => W_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Header_flit_or_Body_flit_not_fake_credit => W_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change => W_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit => W_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_health_info => W_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit => W_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_fault_info => W_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => W_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_valid_in_fault_out_write_fake_flit => W_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop => W_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Body_flit_valid_in_fault_out_fault_info => W_err_state_out_Body_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in => W_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change => W_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => W_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_not_fault_info => W_err_state_out_Body_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info => W_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_not_health_info => W_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
                                                            err_state_out_Body_flit_valid_in_not_health_info => W_err_state_out_Body_flit_valid_in_not_health_info,
                                                            err_state_out_Body_flit_not_fake_credit => W_err_state_out_Body_flit_not_fake_credit,
                                                            err_state_out_Body_flit_not_valid_in_not_write_fake_flit => W_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

                                                            err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit => W_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit => W_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info => W_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => W_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fake_credit => W_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop => W_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fault_info => W_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in => W_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Tail_flit_not_valid_in_state_in_Idle => W_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
                                                            err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change => W_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
                                                            err_state_out_Tail_flit_not_valid_in_not_fault_info => W_err_state_out_Tail_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Tail_flit_not_valid_in_not_fake_credit => W_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
                                                            err_state_out_Tail_flit_not_write_fake_flit => W_err_state_out_Tail_flit_not_write_fake_flit,

                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change => W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change => W_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal => W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change => W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit => W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit => W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change => W_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change => W_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_not_fault_info => W_err_state_out_Packet_drop_not_fault_info,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit => W_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit => W_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit => W_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change => W_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change
            );


FIFO_S: FIFO_credit_based
    generic map ( DATA_WIDTH => DATA_WIDTH)
    port map ( reset => reset, clk => clk, RX => RX_S, valid_in => valid_in_S,
            read_en_N => Grant_NS, read_en_E =>Grant_ES, read_en_W =>Grant_WS, read_en_S =>packet_drop_order_S, read_en_L =>Grant_LS,
            credit_out => credit_out_S, empty_out => empty_S, Data_out => FIFO_D_out_S, fault_info=> faulty_packet_S, health_info=>healthy_packet_S,

                                                            -- Functional checkers
                                                            err_empty_full => S_err_empty_full,
                                                            err_empty_read_en => S_err_empty_read_en,
                                                            err_full_write_en => S_err_full_write_en,
                                                            err_state_in_onehot => S_err_state_in_onehot,
                                                            err_read_pointer_in_onehot => S_err_read_pointer_in_onehot,
                                                            err_write_pointer_in_onehot => S_err_write_pointer_in_onehot,

                                                            -- Structural checkers
                                                            err_write_en_write_pointer => S_err_write_en_write_pointer,
                                                            err_not_write_en_write_pointer => S_err_not_write_en_write_pointer,
                                                            err_read_pointer_write_pointer_not_empty => S_err_read_pointer_write_pointer_not_empty,
                                                            err_read_pointer_write_pointer_empty => S_err_read_pointer_write_pointer_empty,
                                                            err_read_pointer_write_pointer_not_full => S_err_read_pointer_write_pointer_not_full,
                                                            err_read_pointer_write_pointer_full => S_err_read_pointer_write_pointer_full,
                                                            err_read_pointer_increment => S_err_read_pointer_increment,
                                                            err_read_pointer_not_increment => S_err_read_pointer_not_increment,
                                                            err_write_en => S_err_write_en,
                                                            err_not_write_en => S_err_not_write_en,
                                                            err_not_write_en1 => S_err_not_write_en1,
                                                            err_not_write_en2 => S_err_not_write_en2,
                                                            err_read_en_mismatch => S_err_read_en_mismatch,
                                                            err_read_en_mismatch1 => S_err_read_en_mismatch1,

                                                            -- Newly added checkers for FIFO with packet drop and fault classifier support!
                                                            err_fake_credit_read_en_fake_credit_counter_in_increment => S_err_fake_credit_read_en_fake_credit_counter_in_increment,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement => S_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
                                                            err_not_fake_credit_read_en_fake_credit_counter_in_not_change => S_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
                                                            err_fake_credit_not_read_en_fake_credit_counter_in_not_change => S_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change => S_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
                                                            err_fake_credit_read_en_credit_out => S_err_fake_credit_read_en_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out => S_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
                                                            err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out => S_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

                                                            -- Checkers for Packet Dropping FSM of FIFO
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit => S_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
                                                            err_state_out_Idle_not_fault_out_valid_in_state_in_not_change => S_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
                                                            err_state_out_Idle_not_fault_out_not_fake_credit => S_err_state_out_Idle_not_fault_out_not_fake_credit,
                                                            err_state_out_Idle_not_fault_out_not_fault_info => S_err_state_out_Idle_not_fault_out_not_fault_info,
                                                            err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal => S_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Idle_fault_out_fake_credit => S_err_state_out_Idle_fault_out_fake_credit,
                                                            err_state_out_Idle_fault_out_state_in_Packet_drop => S_err_state_out_Idle_fault_out_state_in_Packet_drop,
                                                            err_state_out_Idle_fault_out_fault_info => S_err_state_out_Idle_fault_out_fault_info,
                                                            err_state_out_Idle_fault_out_faulty_packet_in => S_err_state_out_Idle_fault_out_faulty_packet_in,
                                                            err_state_out_Idle_not_health_info => S_err_state_out_Idle_not_health_info,
                                                            err_state_out_Idle_not_write_fake_flit => S_err_state_out_Idle_not_write_fake_flit,

                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit => S_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit => S_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit => S_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info => S_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => S_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_valid_in_fault_out_write_fake_flit => S_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop => S_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Header_flit_valid_in_fault_out_fault_info => S_err_state_out_Header_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in => S_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change => S_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => S_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Header_flit_not_valid_in_not_fault_info => S_err_state_out_Header_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Header_flit_not_valid_in_not_write_fake_flit => S_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Header_flit_or_Body_flit_not_fake_credit => S_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change => S_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit => S_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_health_info => S_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit => S_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_fault_info => S_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => S_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_valid_in_fault_out_write_fake_flit => S_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
                                                            err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop => S_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Body_flit_valid_in_fault_out_fault_info => S_err_state_out_Body_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in => S_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change => S_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => S_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Body_flit_not_valid_in_not_fault_info => S_err_state_out_Body_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info => S_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
                                                            err_state_out_Body_flit_valid_in_fault_out_not_health_info => S_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
                                                            err_state_out_Body_flit_valid_in_not_health_info => S_err_state_out_Body_flit_valid_in_not_health_info,
                                                            err_state_out_Body_flit_not_fake_credit => S_err_state_out_Body_flit_not_fake_credit,
                                                            err_state_out_Body_flit_not_valid_in_not_write_fake_flit => S_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

                                                            err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit => S_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit => S_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info => S_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
                                                            err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => S_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fake_credit => S_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
                                                            err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop => S_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
                                                            err_state_out_Tail_flit_valid_in_fault_out_fault_info => S_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
                                                            err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in => S_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
                                                            err_state_out_Tail_flit_not_valid_in_state_in_Idle => S_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
                                                            err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change => S_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
                                                            err_state_out_Tail_flit_not_valid_in_not_fault_info => S_err_state_out_Tail_flit_not_valid_in_not_fault_info,
                                                            err_state_out_Tail_flit_not_valid_in_not_fake_credit => S_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
                                                            err_state_out_Tail_flit_not_write_fake_flit => S_err_state_out_Tail_flit_not_write_fake_flit,

                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change => S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change => S_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal => S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change => S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit => S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit => S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change => S_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change => S_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
                                                            err_state_out_Packet_drop_not_fault_info => S_err_state_out_Packet_drop_not_fault_info,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit => S_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
                                                            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit => S_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit => S_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
                                                            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change => S_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change
            );


FIFO_L: FIFO_credit_based
    generic map ( DATA_WIDTH => DATA_WIDTH)
    port map ( reset => reset, clk => clk, RX => RX_L, valid_in => valid_in_L,
            read_en_N => Grant_NL, read_en_E =>Grant_EL, read_en_W =>Grant_WL, read_en_S => Grant_SL, read_en_L =>packet_drop_order_L,
            credit_out => credit_out_L, empty_out => empty_L, Data_out => FIFO_D_out_L, fault_info=> faulty_packet_L, health_info=>healthy_packet_L,

            -- Functional checkers
            err_empty_full => L_err_empty_full,
            err_empty_read_en => L_err_empty_read_en,
            err_full_write_en => L_err_full_write_en,
            err_state_in_onehot => L_err_state_in_onehot,
            err_read_pointer_in_onehot => L_err_read_pointer_in_onehot,
            err_write_pointer_in_onehot => L_err_write_pointer_in_onehot,

            -- Structural checkers
            err_write_en_write_pointer => L_err_write_en_write_pointer,
            err_not_write_en_write_pointer => L_err_not_write_en_write_pointer,
            err_read_pointer_write_pointer_not_empty => L_err_read_pointer_write_pointer_not_empty,
            err_read_pointer_write_pointer_empty => L_err_read_pointer_write_pointer_empty,
            err_read_pointer_write_pointer_not_full => L_err_read_pointer_write_pointer_not_full,
            err_read_pointer_write_pointer_full => L_err_read_pointer_write_pointer_full,
            err_read_pointer_increment => L_err_read_pointer_increment,
            err_read_pointer_not_increment => L_err_read_pointer_not_increment,
            err_write_en => L_err_write_en,
            err_not_write_en => L_err_not_write_en,
            err_not_write_en1 => L_err_not_write_en1,
            err_not_write_en2 => L_err_not_write_en2,
            err_read_en_mismatch => L_err_read_en_mismatch,
            err_read_en_mismatch1 => L_err_read_en_mismatch1,

            -- Newly added checkers for FIFO with packet drop and fault classifier support!
            err_fake_credit_read_en_fake_credit_counter_in_increment => L_err_fake_credit_read_en_fake_credit_counter_in_increment,
            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement => L_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_fake_credit_counter_in_decrement,
            err_not_fake_credit_read_en_fake_credit_counter_in_not_change => L_err_not_fake_credit_read_en_fake_credit_counter_in_not_change,
            err_fake_credit_not_read_en_fake_credit_counter_in_not_change => L_err_fake_credit_not_read_en_fake_credit_counter_in_not_change,
            err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change => L_err_not_fake_credit_not_read_en_fake_credit_counter_zero_fake_credit_counter_in_not_change,
            err_fake_credit_read_en_credit_out => L_err_fake_credit_read_en_credit_out,
            err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out => L_err_not_fake_credit_not_read_en_fake_credit_counter_not_zero_credit_out,
            err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out => L_err_not_fake_credit_not_read_en_fake_credit_counter_zero_not_credit_out,

            -- Checkers for Packet Dropping FSM of FIFO
            err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit => L_err_state_out_Idle_not_fault_out_valid_in_state_in_Header_flit,
            err_state_out_Idle_not_fault_out_valid_in_state_in_not_change => L_err_state_out_Idle_not_fault_out_valid_in_state_in_not_change,
            err_state_out_Idle_not_fault_out_not_fake_credit => L_err_state_out_Idle_not_fault_out_not_fake_credit,
            err_state_out_Idle_not_fault_out_not_fault_info => L_err_state_out_Idle_not_fault_out_not_fault_info,
            err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal => L_err_state_out_Idle_not_fault_out_faulty_packet_in_faulty_packet_out_equal,
            err_state_out_Idle_fault_out_fake_credit => L_err_state_out_Idle_fault_out_fake_credit,
            err_state_out_Idle_fault_out_state_in_Packet_drop => L_err_state_out_Idle_fault_out_state_in_Packet_drop,
            err_state_out_Idle_fault_out_fault_info => L_err_state_out_Idle_fault_out_fault_info,
            err_state_out_Idle_fault_out_faulty_packet_in => L_err_state_out_Idle_fault_out_faulty_packet_in,
            err_state_out_Idle_not_health_info => L_err_state_out_Idle_not_health_info,
            err_state_out_Idle_not_write_fake_flit => L_err_state_out_Idle_not_write_fake_flit,

            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit => L_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Body_state_in_Body_flit,
            err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit => L_err_state_out_Header_flit_valid_in_not_fault_out_flit_type_Tail_state_in_Tail_flit,
            err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit => L_err_state_out_Header_flit_valid_in_not_fault_out_not_write_fake_flit,
            err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info => L_err_state_out_Header_flit_valid_in_not_fault_out_not_fault_info,
            err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => L_err_state_out_Header_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            err_state_out_Header_flit_valid_in_fault_out_write_fake_flit => L_err_state_out_Header_flit_valid_in_fault_out_write_fake_flit,
            err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop => L_err_state_out_Header_flit_valid_in_fault_out_state_in_Packet_drop,
            err_state_out_Header_flit_valid_in_fault_out_fault_info => L_err_state_out_Header_flit_valid_in_fault_out_fault_info,
            err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in => L_err_state_out_Header_flit_valid_in_fault_out_faulty_packet_in,
            err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change => L_err_state_out_Header_flit_not_valid_in_state_in_state_out_not_change,
            err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => L_err_state_out_Header_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            err_state_out_Header_flit_not_valid_in_not_fault_info => L_err_state_out_Header_flit_not_valid_in_not_fault_info,
            err_state_out_Header_flit_not_valid_in_not_write_fake_flit => L_err_state_out_Header_flit_not_valid_in_not_write_fake_flit,
            err_state_out_Header_flit_or_Body_flit_not_fake_credit => L_err_state_out_Header_flit_or_Body_flit_not_fake_credit,

            err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change => L_err_state_out_Body_flit_valid_in_not_fault_out_state_in_state_out_not_change,
            err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit => L_err_state_out_Body_flit_valid_in_not_fault_out_state_in_Tail_flit,
            err_state_out_Body_flit_valid_in_not_fault_out_health_info => L_err_state_out_Body_flit_valid_in_not_fault_out_health_info,
            err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit => L_err_state_out_Body_flit_valid_in_not_fault_out_not_write_fake_flit,
            err_state_out_Body_flit_valid_in_not_fault_out_fault_info => L_err_state_out_Body_flit_valid_in_not_fault_out_fault_info,
            err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => L_err_state_out_Body_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            err_state_out_Body_flit_valid_in_fault_out_write_fake_flit => L_err_state_out_Body_flit_valid_in_fault_out_write_fake_flit,
            err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop => L_err_state_out_Body_flit_valid_in_fault_out_state_in_Packet_drop,
            err_state_out_Body_flit_valid_in_fault_out_fault_info => L_err_state_out_Body_flit_valid_in_fault_out_fault_info,
            err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in => L_err_state_out_Body_flit_valid_in_fault_out_faulty_packet_in,
            err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change => L_err_state_out_Body_flit_not_valid_in_state_in_state_out_not_change,
            err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change => L_err_state_out_Body_flit_not_valid_in_faulty_packet_in_faulty_packet_out_not_change,
            err_state_out_Body_flit_not_valid_in_not_fault_info => L_err_state_out_Body_flit_not_valid_in_not_fault_info,
            err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info => L_err_state_out_Body_flit_valid_in_not_fault_out_flit_type_not_tail_not_health_info,
            err_state_out_Body_flit_valid_in_fault_out_not_health_info => L_err_state_out_Body_flit_valid_in_fault_out_not_health_info,
            err_state_out_Body_flit_valid_in_not_health_info => L_err_state_out_Body_flit_valid_in_not_health_info,
            err_state_out_Body_flit_not_fake_credit => L_err_state_out_Body_flit_not_fake_credit,
            err_state_out_Body_flit_not_valid_in_not_write_fake_flit => L_err_state_out_Body_flit_not_valid_in_not_write_fake_flit,

            err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit => L_err_state_out_Tail_flit_valid_in_not_fault_out_flit_type_Header_state_in_Header_flit,
            err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit => L_err_state_out_Tail_flit_valid_in_not_fault_out_not_fake_credit,
            err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info => L_err_state_out_Tail_flit_valid_in_not_fault_out_not_fault_info,
            err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change => L_err_state_out_Tail_flit_valid_in_not_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            err_state_out_Tail_flit_valid_in_fault_out_fake_credit => L_err_state_out_Tail_flit_valid_in_fault_out_fake_credit,
            err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop => L_err_state_out_Tail_flit_valid_in_fault_out_state_in_Packet_drop,
            err_state_out_Tail_flit_valid_in_fault_out_fault_info => L_err_state_out_Tail_flit_valid_in_fault_out_fault_info,
            err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in => L_err_state_out_Tail_flit_valid_in_fault_out_faulty_packet_in,
            err_state_out_Tail_flit_not_valid_in_state_in_Idle => L_err_state_out_Tail_flit_not_valid_in_state_in_Idle,
            err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change => L_err_state_out_Tail_flit_not_valid_in_faulty_packet_in_faulty_packet_in_not_change,
            err_state_out_Tail_flit_not_valid_in_not_fault_info => L_err_state_out_Tail_flit_not_valid_in_not_fault_info,
            err_state_out_Tail_flit_not_valid_in_not_fake_credit => L_err_state_out_Tail_flit_not_valid_in_not_fake_credit,
            err_state_out_Tail_flit_not_write_fake_flit => L_err_state_out_Tail_flit_not_write_fake_flit,

            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_fake_credit,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_not_faulty_packet_in,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_state_in_Header_flit,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_not_fault_out_write_fake_flit,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_faulty_packet_in,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_not_state_in_Idle,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_not_fault_out_fake_credit,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_invalid_fault_out_fake_credit,
            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change => L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_flit_type_body_or_invalid_fault_out_faulty_packet_in_faulty_packet_out_not_change,
            err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change => L_err_state_out_Packet_drop_faulty_packet_out_flit_type_invalid_fault_out_state_in_state_out_not_change,
            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal => L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_faulty_packet_in_faulty_packet_out_equal,
            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change => L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_state_in_state_out_not_change,
            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit => L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_write_fake_flit,
            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit => L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_not_fake_credit,
            err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change => L_err_state_out_Packet_drop_not_faulty_packet_out_state_in_state_out_not_change,
            err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change => L_err_state_out_Packet_drop_not_faulty_packet_out_faulty_packet_in_faulty_packet_out_not_change,
            err_state_out_Packet_drop_not_fault_info => L_err_state_out_Packet_drop_not_fault_info,
            err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit => L_err_state_out_Packet_drop_not_faulty_packet_out_not_fake_credit,
            err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit => L_err_state_out_Packet_drop_faulty_packet_out_not_valid_in_or_flit_type_not_header_or_fault_out_not_write_fake_flit,
            err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit => L_err_state_out_Packet_drop_not_faulty_packet_out_not_write_fake_flit,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Header_fault_out_state_in_state_out_not_change,
            err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change => L_err_state_out_Packet_drop_faulty_packet_out_valid_in_flit_type_Tail_fault_out_state_in_state_out_not_change
            );

------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

--- all the LBDRs
LBDR_N: LBDR_packet_drop generic map (cur_addr_rst => current_address, Cx_rst => Cx_rst, NoC_size => NoC_size)
       PORT MAP (reset => reset, clk => clk, empty => empty_N, Rxy_reconf => Rxy_reconf, Reconfig => Reconfig,
       		 Faulty_C_N => Faulty_N_in, Faulty_C_E => Faulty_E_in, Faulty_C_W => Faulty_W_in, Faulty_C_S => Faulty_S_in,
             flit_type => FIFO_D_out_N(DATA_WIDTH-1 downto DATA_WIDTH-3), dst_addr=> FIFO_D_out_N(NoC_size  downto 1) ,
             packet_drop_order => packet_drop_order_N,
             grant_N => '0', grant_E =>Grant_EN, grant_W => Grant_WN, grant_S=>Grant_SN, grant_L =>Grant_LN,
             Req_N=> Req_NN, Req_E=>Req_NE, Req_W=>Req_NW, Req_S=>Req_NS, Req_L=>Req_NL,

             -- Checker outputs
            err_header_empty_Requests_FF_Requests_in => N_err_header_empty_Requests_FF_Requests_in,
            err_tail_Requests_in_all_zero => N_err_tail_Requests_in_all_zero,
            err_tail_empty_Requests_FF_Requests_in => N_err_tail_empty_Requests_FF_Requests_in,
            err_tail_not_empty_not_grants_Requests_FF_Requests_in => N_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            err_grants_onehot => N_err_grants_onehot,
            err_grants_mismatch => N_err_grants_mismatch,
            err_header_tail_Requests_FF_Requests_in => N_err_header_tail_Requests_FF_Requests_in,
            err_dst_addr_cur_addr_N1 => N_err_dst_addr_cur_addr_N1,
            err_dst_addr_cur_addr_not_N1 => N_err_dst_addr_cur_addr_not_N1,
            err_dst_addr_cur_addr_E1 => N_err_dst_addr_cur_addr_E1,
            err_dst_addr_cur_addr_not_E1 => N_err_dst_addr_cur_addr_not_E1,
            err_dst_addr_cur_addr_W1 => N_err_dst_addr_cur_addr_W1,
            err_dst_addr_cur_addr_not_W1 => N_err_dst_addr_cur_addr_not_W1,
            err_dst_addr_cur_addr_S1 => N_err_dst_addr_cur_addr_S1,
            err_dst_addr_cur_addr_not_S1 => N_err_dst_addr_cur_addr_not_S1,
            err_dst_addr_cur_addr_not_Req_L_in => N_err_dst_addr_cur_addr_not_Req_L_in,
            err_dst_addr_cur_addr_Req_L_in => N_err_dst_addr_cur_addr_Req_L_in,
            err_header_not_empty_Req_N_in => N_err_header_not_empty_Req_N_in,
            err_header_not_empty_Req_E_in => N_err_header_not_empty_Req_E_in,
            err_header_not_empty_Req_W_in => N_err_header_not_empty_Req_W_in,
            err_header_not_empty_Req_S_in => N_err_header_not_empty_Req_S_in,
            err_header_not_empty_packet_drop_in => N_err_header_not_empty_packet_drop_in,
            err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal => N_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            err_header_empty_packet_drop_in_packet_drop_equal => N_err_header_empty_packet_drop_in_packet_drop_equal,
            err_tail_not_empty_packet_drop_not_packet_drop_in => N_err_tail_not_empty_packet_drop_not_packet_drop_in,
            err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal => N_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            err_invalid_or_body_flit_packet_drop_in_packet_drop_equal => N_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            err_packet_drop_order => N_err_packet_drop_order,

            err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal => N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in => N_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal => N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in => N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in => N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal => N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal => N_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal => N_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal => N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in => N_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal => N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in => N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal => N_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal
             );

LBDR_E: LBDR_packet_drop generic map (cur_addr_rst => current_address, Cx_rst => Cx_rst, NoC_size => NoC_size)
   PORT MAP (reset =>  reset, clk => clk, empty => empty_E, Rxy_reconf => Rxy_reconf, Reconfig => Reconfig,
   	 		 Faulty_C_N => Faulty_N_in, Faulty_C_E => Faulty_E_in, Faulty_C_W => Faulty_W_in, Faulty_C_S => Faulty_S_in,
             flit_type => FIFO_D_out_E(DATA_WIDTH-1 downto DATA_WIDTH-3), dst_addr=> FIFO_D_out_E(NoC_size  downto 1) ,
             packet_drop_order => packet_drop_order_E,
             grant_N => Grant_NE, grant_E =>'0', grant_W => Grant_WE, grant_S=>Grant_SE, grant_L =>Grant_LE,
             Req_N=> Req_EN, Req_E=>Req_EE, Req_W=>Req_EW, Req_S=>Req_ES, Req_L=>Req_EL,

             -- Checker outputs
            err_header_empty_Requests_FF_Requests_in => E_err_header_empty_Requests_FF_Requests_in,
            err_tail_Requests_in_all_zero => E_err_tail_Requests_in_all_zero,
            err_tail_empty_Requests_FF_Requests_in => E_err_tail_empty_Requests_FF_Requests_in,
            err_tail_not_empty_not_grants_Requests_FF_Requests_in => E_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            err_grants_onehot => E_err_grants_onehot,
            err_grants_mismatch => E_err_grants_mismatch,
            err_header_tail_Requests_FF_Requests_in => E_err_header_tail_Requests_FF_Requests_in,
            err_dst_addr_cur_addr_N1 => E_err_dst_addr_cur_addr_N1,
            err_dst_addr_cur_addr_not_N1 => E_err_dst_addr_cur_addr_not_N1,
            err_dst_addr_cur_addr_E1 => E_err_dst_addr_cur_addr_E1,
            err_dst_addr_cur_addr_not_E1 => E_err_dst_addr_cur_addr_not_E1,
            err_dst_addr_cur_addr_W1 => E_err_dst_addr_cur_addr_W1,
            err_dst_addr_cur_addr_not_W1 => E_err_dst_addr_cur_addr_not_W1,
            err_dst_addr_cur_addr_S1 => E_err_dst_addr_cur_addr_S1,
            err_dst_addr_cur_addr_not_S1 => E_err_dst_addr_cur_addr_not_S1,
            err_dst_addr_cur_addr_not_Req_L_in => E_err_dst_addr_cur_addr_not_Req_L_in,
            err_dst_addr_cur_addr_Req_L_in => E_err_dst_addr_cur_addr_Req_L_in,
            err_header_not_empty_Req_N_in => E_err_header_not_empty_Req_N_in,
            err_header_not_empty_Req_E_in => E_err_header_not_empty_Req_E_in,
            err_header_not_empty_Req_W_in => E_err_header_not_empty_Req_W_in,
            err_header_not_empty_Req_S_in => E_err_header_not_empty_Req_S_in,
            err_header_not_empty_packet_drop_in => E_err_header_not_empty_packet_drop_in,
            err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal => E_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            err_header_empty_packet_drop_in_packet_drop_equal => E_err_header_empty_packet_drop_in_packet_drop_equal,
            err_tail_not_empty_packet_drop_not_packet_drop_in => E_err_tail_not_empty_packet_drop_not_packet_drop_in,
            err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal => E_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            err_invalid_or_body_flit_packet_drop_in_packet_drop_equal => E_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            err_packet_drop_order => E_err_packet_drop_order,

            err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal => E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in => E_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal => E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in => E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in => E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal => E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal => E_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal => E_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal => E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in => E_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal => E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in => E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal => E_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal
             );

LBDR_W: LBDR_packet_drop generic map (cur_addr_rst => current_address, Cx_rst => Cx_rst, NoC_size => NoC_size)
   PORT MAP (reset =>  reset, clk => clk, empty => empty_W,  Rxy_reconf => Rxy_reconf, Reconfig => Reconfig,
   			 Faulty_C_N => Faulty_N_in, Faulty_C_E => Faulty_E_in, Faulty_C_W => Faulty_W_in, Faulty_C_S => Faulty_S_in,
             flit_type => FIFO_D_out_W(DATA_WIDTH-1 downto DATA_WIDTH-3), dst_addr=> FIFO_D_out_W(NoC_size  downto 1) ,
             packet_drop_order => packet_drop_order_W,
             grant_N => Grant_NW, grant_E =>Grant_EW, grant_W =>'0' ,grant_S=>Grant_SW, grant_L =>Grant_LW,
             Req_N=> Req_WN, Req_E=>Req_WE, Req_W=>Req_WW, Req_S=>Req_WS, Req_L=>Req_WL,

             -- Checker outputs
            err_header_empty_Requests_FF_Requests_in => W_err_header_empty_Requests_FF_Requests_in,
            err_tail_Requests_in_all_zero => W_err_tail_Requests_in_all_zero,
            err_tail_empty_Requests_FF_Requests_in => W_err_tail_empty_Requests_FF_Requests_in,
            err_tail_not_empty_not_grants_Requests_FF_Requests_in => W_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            err_grants_onehot => W_err_grants_onehot,
            err_grants_mismatch => W_err_grants_mismatch,
            err_header_tail_Requests_FF_Requests_in => W_err_header_tail_Requests_FF_Requests_in,
            err_dst_addr_cur_addr_N1 => W_err_dst_addr_cur_addr_N1,
            err_dst_addr_cur_addr_not_N1 => W_err_dst_addr_cur_addr_not_N1,
            err_dst_addr_cur_addr_E1 => W_err_dst_addr_cur_addr_E1,
            err_dst_addr_cur_addr_not_E1 => W_err_dst_addr_cur_addr_not_E1,
            err_dst_addr_cur_addr_W1 => W_err_dst_addr_cur_addr_W1,
            err_dst_addr_cur_addr_not_W1 => W_err_dst_addr_cur_addr_not_W1,
            err_dst_addr_cur_addr_S1 => W_err_dst_addr_cur_addr_S1,
            err_dst_addr_cur_addr_not_S1 => W_err_dst_addr_cur_addr_not_S1,
            err_dst_addr_cur_addr_not_Req_L_in => W_err_dst_addr_cur_addr_not_Req_L_in,
            err_dst_addr_cur_addr_Req_L_in => W_err_dst_addr_cur_addr_Req_L_in,
            err_header_not_empty_Req_N_in => W_err_header_not_empty_Req_N_in,
            err_header_not_empty_Req_E_in => W_err_header_not_empty_Req_E_in,
            err_header_not_empty_Req_W_in => W_err_header_not_empty_Req_W_in,
            err_header_not_empty_Req_S_in => W_err_header_not_empty_Req_S_in,
            err_header_not_empty_packet_drop_in => W_err_header_not_empty_packet_drop_in,
            err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal => W_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            err_header_empty_packet_drop_in_packet_drop_equal => W_err_header_empty_packet_drop_in_packet_drop_equal,
            err_tail_not_empty_packet_drop_not_packet_drop_in => W_err_tail_not_empty_packet_drop_not_packet_drop_in,
            err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal => W_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            err_invalid_or_body_flit_packet_drop_in_packet_drop_equal => W_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            err_packet_drop_order => W_err_packet_drop_order,

            err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal => W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in => W_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal => W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in => W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in => W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal => W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal => W_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal => W_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal => W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in => W_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal => W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in => W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal => W_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal
             );

LBDR_S: LBDR_packet_drop generic map (cur_addr_rst => current_address, Cx_rst => Cx_rst, NoC_size => NoC_size)
   PORT MAP (reset =>  reset, clk => clk, empty => empty_S, Rxy_reconf => Rxy_reconf, Reconfig => Reconfig,
   			 Faulty_C_N => Faulty_N_in, Faulty_C_E => Faulty_E_in, Faulty_C_W => Faulty_W_in, Faulty_C_S => Faulty_S_in,
             flit_type => FIFO_D_out_S(DATA_WIDTH-1 downto DATA_WIDTH-3), dst_addr=> FIFO_D_out_S(NoC_size  downto 1) ,
             packet_drop_order => packet_drop_order_S,
             grant_N => Grant_NS, grant_E =>Grant_ES, grant_W =>Grant_WS ,grant_S=>'0', grant_L =>Grant_LS,
             Req_N=> Req_SN, Req_E=>Req_SE, Req_W=>Req_SW, Req_S=>Req_SS, Req_L=>Req_SL,

             -- Checker outputs
            err_header_empty_Requests_FF_Requests_in => S_err_header_empty_Requests_FF_Requests_in,
            err_tail_Requests_in_all_zero => S_err_tail_Requests_in_all_zero,
            err_tail_empty_Requests_FF_Requests_in => S_err_tail_empty_Requests_FF_Requests_in,
            err_tail_not_empty_not_grants_Requests_FF_Requests_in => S_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            err_grants_onehot => S_err_grants_onehot,
            err_grants_mismatch => S_err_grants_mismatch,
            err_header_tail_Requests_FF_Requests_in => S_err_header_tail_Requests_FF_Requests_in,
            err_dst_addr_cur_addr_N1 => S_err_dst_addr_cur_addr_N1,
            err_dst_addr_cur_addr_not_N1 => S_err_dst_addr_cur_addr_not_N1,
            err_dst_addr_cur_addr_E1 => S_err_dst_addr_cur_addr_E1,
            err_dst_addr_cur_addr_not_E1 => S_err_dst_addr_cur_addr_not_E1,
            err_dst_addr_cur_addr_W1 => S_err_dst_addr_cur_addr_W1,
            err_dst_addr_cur_addr_not_W1 => S_err_dst_addr_cur_addr_not_W1,
            err_dst_addr_cur_addr_S1 => S_err_dst_addr_cur_addr_S1,
            err_dst_addr_cur_addr_not_S1 => S_err_dst_addr_cur_addr_not_S1,
            err_dst_addr_cur_addr_not_Req_L_in => S_err_dst_addr_cur_addr_not_Req_L_in,
            err_dst_addr_cur_addr_Req_L_in => S_err_dst_addr_cur_addr_Req_L_in,
            err_header_not_empty_Req_N_in => S_err_header_not_empty_Req_N_in,
            err_header_not_empty_Req_E_in => S_err_header_not_empty_Req_E_in,
            err_header_not_empty_Req_W_in => S_err_header_not_empty_Req_W_in,
            err_header_not_empty_Req_S_in => S_err_header_not_empty_Req_S_in,
            err_header_not_empty_packet_drop_in => S_err_header_not_empty_packet_drop_in,
            err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal => S_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            err_header_empty_packet_drop_in_packet_drop_equal => S_err_header_empty_packet_drop_in_packet_drop_equal,
            err_tail_not_empty_packet_drop_not_packet_drop_in => S_err_tail_not_empty_packet_drop_not_packet_drop_in,
            err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal => S_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            err_invalid_or_body_flit_packet_drop_in_packet_drop_equal => S_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            err_packet_drop_order => S_err_packet_drop_order,

            err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal => S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in => S_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal => S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in => S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in => S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal => S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal => S_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal => S_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal => S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in => S_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal => S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in => S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal => S_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal
             );

LBDR_L: LBDR_packet_drop generic map (cur_addr_rst => current_address, Cx_rst => Cx_rst, NoC_size => NoC_size)
   PORT MAP (reset =>  reset, clk => clk, empty => empty_L, Rxy_reconf => Rxy_reconf, Reconfig => Reconfig,
   			 Faulty_C_N => Faulty_N_in, Faulty_C_E => Faulty_E_in, Faulty_C_W => Faulty_W_in, Faulty_C_S => Faulty_S_in,
             flit_type => FIFO_D_out_L(DATA_WIDTH-1 downto DATA_WIDTH-3), dst_addr=> FIFO_D_out_L(NoC_size  downto 1) ,
             packet_drop_order => packet_drop_order_L,
             grant_N => Grant_NL, grant_E =>Grant_EL, grant_W => Grant_WL,grant_S=>Grant_SL, grant_L =>'0',
             Req_N=> Req_LN, Req_E=>Req_LE, Req_W=>Req_LW, Req_S=>Req_LS, Req_L=>Req_LL,

             -- Checker outputs
            err_header_empty_Requests_FF_Requests_in => L_err_header_empty_Requests_FF_Requests_in,
            err_tail_Requests_in_all_zero => L_err_tail_Requests_in_all_zero,
            err_tail_empty_Requests_FF_Requests_in => L_err_tail_empty_Requests_FF_Requests_in,
            err_tail_not_empty_not_grants_Requests_FF_Requests_in => L_err_tail_not_empty_not_grants_Requests_FF_Requests_in,
            err_grants_onehot => L_err_grants_onehot,
            err_grants_mismatch => L_err_grants_mismatch,
            err_header_tail_Requests_FF_Requests_in => L_err_header_tail_Requests_FF_Requests_in,
            err_dst_addr_cur_addr_N1 => L_err_dst_addr_cur_addr_N1,
            err_dst_addr_cur_addr_not_N1 => L_err_dst_addr_cur_addr_not_N1,
            err_dst_addr_cur_addr_E1 => L_err_dst_addr_cur_addr_E1,
            err_dst_addr_cur_addr_not_E1 => L_err_dst_addr_cur_addr_not_E1,
            err_dst_addr_cur_addr_W1 => L_err_dst_addr_cur_addr_W1,
            err_dst_addr_cur_addr_not_W1 => L_err_dst_addr_cur_addr_not_W1,
            err_dst_addr_cur_addr_S1 => L_err_dst_addr_cur_addr_S1,
            err_dst_addr_cur_addr_not_S1 => L_err_dst_addr_cur_addr_not_S1,
            err_dst_addr_cur_addr_not_Req_L_in => L_err_dst_addr_cur_addr_not_Req_L_in,
            err_dst_addr_cur_addr_Req_L_in => L_err_dst_addr_cur_addr_Req_L_in,
            err_header_not_empty_Req_N_in => L_err_header_not_empty_Req_N_in,
            err_header_not_empty_Req_E_in => L_err_header_not_empty_Req_E_in,
            err_header_not_empty_Req_W_in => L_err_header_not_empty_Req_W_in,
            err_header_not_empty_Req_S_in => L_err_header_not_empty_Req_S_in,
            err_header_not_empty_packet_drop_in => L_err_header_not_empty_packet_drop_in,
            err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal => L_err_header_not_empty_dst_addr_cur_addr_equal_packet_drop_in_packet_drop_equal,
            err_header_empty_packet_drop_in_packet_drop_equal => L_err_header_empty_packet_drop_in_packet_drop_equal,
            err_tail_not_empty_packet_drop_not_packet_drop_in => L_err_tail_not_empty_packet_drop_not_packet_drop_in,
            err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal => L_err_tail_not_empty_not_packet_drop_packet_drop_in_packet_drop_equal,
            err_invalid_or_body_flit_packet_drop_in_packet_drop_equal => L_err_invalid_or_body_flit_packet_drop_in_packet_drop_equal,
            err_packet_drop_order => L_err_packet_drop_order,

            err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal => L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Cx_in_Temp_Cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in => L_err_reconfig_cx_flit_type_Tail_not_empty_grants_not_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal => L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Cx_in_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in => L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_reconfig_cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in => L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_Faulty_C_Temp_Cx_in,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal => L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_reconfig_cx_in_reconfig_cx_equal,
            err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal => L_err_reconfig_cx_flit_type_Tail_not_empty_grants_Temp_Cx_in_Temp_Cx_equal,
            err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal => L_err_not_reconfig_cx_flit_type_not_Tail_empty_not_grants_not_Faulty_C_Temp_Cx_in_Temp_Cx_equal,

            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal => L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_Rxy_in_Rxy_reconf_equal,
            err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in => L_err_ReConf_FF_out_flit_type_Tail_not_empty_grants_not_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal => L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Rxy_in_Rxy_equal,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in => L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_Reconfig_ReConf_FF_in,
            err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal => L_err_not_ReConf_FF_out_flit_type_not_Tail_empty_not_grants_not_Reconfig_ReConf_FF_in_ReConf_FF_out_equal
             );

------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

-- switch allocator

allocator_unit: allocator port map ( reset => reset, clk => clk,
            -- flow control
            credit_in_N => credit_in_N, credit_in_E => credit_in_E, credit_in_W => credit_in_W, credit_in_S => credit_in_S, credit_in_L => credit_in_L,

            -- requests from the LBDRS
            req_N_N => '0', req_N_E => Req_NE, req_N_W => Req_NW, req_N_S => Req_NS, req_N_L => Req_NL,
            req_E_N => Req_EN, req_E_E => '0', req_E_W => Req_EW, req_E_S => Req_ES, req_E_L => Req_EL,
            req_W_N => Req_WN, req_W_E => Req_WE, req_W_W => '0', req_W_S => Req_WS, req_W_L => Req_WL,
            req_S_N => Req_SN, req_S_E => Req_SE, req_S_W => Req_SW, req_S_S => '0', req_S_L => Req_SL,
            req_L_N => Req_LN, req_L_E => Req_LE, req_L_W => Req_LW, req_L_S => Req_LS, req_L_L => '0',
            empty_N => empty_N, empty_E => empty_E, empty_w => empty_W, empty_S => empty_S, empty_L => empty_L,
            valid_N => valid_out_N, valid_E => valid_out_E, valid_W => valid_out_W, valid_S => valid_out_S, valid_L => valid_out_L,
            -- grant_X_Y means the grant for X output port towards Y input port
            -- this means for any X in [N, E, W, S, L] then set grant_X_Y is one hot!
            grant_N_N => Grant_NN, grant_N_E => Grant_NE, grant_N_W => Grant_NW, grant_N_S => Grant_NS, grant_N_L => Grant_NL,
            grant_E_N => Grant_EN, grant_E_E => Grant_EE, grant_E_W => Grant_EW, grant_E_S => Grant_ES, grant_E_L => Grant_EL,
            grant_W_N => Grant_WN, grant_W_E => Grant_WE, grant_W_W => Grant_WW, grant_W_S => Grant_WS, grant_W_L => Grant_WL,
            grant_S_N => Grant_SN, grant_S_E => Grant_SE, grant_S_W => Grant_SW, grant_S_S => Grant_SS, grant_S_L => Grant_SL,
            grant_L_N => Grant_LN, grant_L_E => Grant_LE, grant_L_W => Grant_LW, grant_L_S => Grant_LS, grant_L_L => Grant_LL,

            -- Checker outputs
            -- Allocator logic checker outputs
            err_grant_N_N_sig_not_empty_N_grant_N_N  => err_grant_N_N_sig_not_empty_N_grant_N_N ,
            err_not_grant_N_N_sig_or_empty_N_not_grant_N_N  => err_not_grant_N_N_sig_or_empty_N_not_grant_N_N ,
            err_grant_N_E_sig_not_empty_E_grant_N_E  => err_grant_N_E_sig_not_empty_E_grant_N_E ,
            err_not_grant_N_E_sig_or_empty_E_not_grant_N_E  => err_not_grant_N_E_sig_or_empty_E_not_grant_N_E ,
            err_grant_N_W_sig_not_empty_W_grant_N_W  => err_grant_N_W_sig_not_empty_W_grant_N_W ,
            err_not_grant_N_W_sig_or_empty_W_not_grant_N_W  => err_not_grant_N_W_sig_or_empty_W_not_grant_N_W ,
            err_grant_N_S_sig_not_empty_S_grant_N_S  => err_grant_N_S_sig_not_empty_S_grant_N_S ,
            err_not_grant_N_S_sig_or_empty_S_not_grant_N_S  => err_not_grant_N_S_sig_or_empty_S_not_grant_N_S ,
            err_grant_N_L_sig_not_empty_L_grant_N_L  => err_grant_N_L_sig_not_empty_L_grant_N_L ,
            err_not_grant_N_L_sig_or_empty_L_not_grant_N_L  => err_not_grant_N_L_sig_or_empty_L_not_grant_N_L ,

            err_grant_E_N_sig_not_empty_N_grant_E_N  => err_grant_E_N_sig_not_empty_N_grant_E_N ,
            err_not_grant_E_N_sig_or_empty_N_not_grant_E_N  => err_not_grant_E_N_sig_or_empty_N_not_grant_E_N ,
            err_grant_E_E_sig_not_empty_E_grant_E_E  => err_grant_E_E_sig_not_empty_E_grant_E_E ,
            err_not_grant_E_E_sig_or_empty_E_not_grant_E_E  => err_not_grant_E_E_sig_or_empty_E_not_grant_E_E ,
            err_grant_E_W_sig_not_empty_W_grant_E_W  => err_grant_E_W_sig_not_empty_W_grant_E_W ,
            err_not_grant_E_W_sig_or_empty_W_not_grant_E_W  => err_not_grant_E_W_sig_or_empty_W_not_grant_E_W ,
            err_grant_E_S_sig_not_empty_S_grant_E_S  => err_grant_E_S_sig_not_empty_S_grant_E_S ,
            err_not_grant_E_S_sig_or_empty_S_not_grant_E_S  => err_not_grant_E_S_sig_or_empty_S_not_grant_E_S ,
            err_grant_E_L_sig_not_empty_L_grant_E_L  => err_grant_E_L_sig_not_empty_L_grant_E_L ,
            err_not_grant_E_L_sig_or_empty_L_not_grant_E_L  => err_not_grant_E_L_sig_or_empty_L_not_grant_E_L ,

            err_grant_W_N_sig_not_empty_N_grant_W_N  => err_grant_W_N_sig_not_empty_N_grant_W_N ,
            err_not_grant_W_N_sig_or_empty_N_not_grant_W_N  => err_not_grant_W_N_sig_or_empty_N_not_grant_W_N ,
            err_grant_W_E_sig_not_empty_E_grant_W_E  => err_grant_W_E_sig_not_empty_E_grant_W_E ,
            err_not_grant_W_E_sig_or_empty_E_not_grant_W_E  => err_not_grant_W_E_sig_or_empty_E_not_grant_W_E ,
            err_grant_W_W_sig_not_empty_W_grant_W_W  => err_grant_W_W_sig_not_empty_W_grant_W_W ,
            err_not_grant_W_W_sig_or_empty_W_not_grant_W_W  => err_not_grant_W_W_sig_or_empty_W_not_grant_W_W ,
            err_grant_W_S_sig_not_empty_S_grant_W_S  => err_grant_W_S_sig_not_empty_S_grant_W_S ,
            err_not_grant_W_S_sig_or_empty_S_not_grant_W_S  => err_not_grant_W_S_sig_or_empty_S_not_grant_W_S ,
            err_grant_W_L_sig_not_empty_L_grant_W_L  => err_grant_W_L_sig_not_empty_L_grant_W_L ,
            err_not_grant_W_L_sig_or_empty_L_not_grant_W_L  => err_not_grant_W_L_sig_or_empty_L_not_grant_W_L ,

            err_grant_S_N_sig_not_empty_N_grant_S_N  => err_grant_S_N_sig_not_empty_N_grant_S_N ,
            err_not_grant_S_N_sig_or_empty_N_not_grant_S_N  => err_not_grant_S_N_sig_or_empty_N_not_grant_S_N ,
            err_grant_S_E_sig_not_empty_E_grant_S_E  => err_grant_S_E_sig_not_empty_E_grant_S_E ,
            err_not_grant_S_E_sig_or_empty_E_not_grant_S_E  => err_not_grant_S_E_sig_or_empty_E_not_grant_S_E ,
            err_grant_S_W_sig_not_empty_W_grant_S_W  => err_grant_S_W_sig_not_empty_W_grant_S_W ,
            err_not_grant_S_W_sig_or_empty_W_not_grant_S_W  => err_not_grant_S_W_sig_or_empty_W_not_grant_S_W ,
            err_grant_S_S_sig_not_empty_S_grant_S_S  => err_grant_S_S_sig_not_empty_S_grant_S_S ,
            err_not_grant_S_S_sig_or_empty_S_not_grant_S_S  => err_not_grant_S_S_sig_or_empty_S_not_grant_S_S ,
            err_grant_S_L_sig_not_empty_L_grant_S_L  => err_grant_S_L_sig_not_empty_L_grant_S_L ,
            err_not_grant_S_L_sig_or_empty_L_not_grant_S_L  => err_not_grant_S_L_sig_or_empty_L_not_grant_S_L ,

            err_grant_L_N_sig_not_empty_N_grant_L_N => err_grant_L_N_sig_not_empty_N_grant_L_N ,
            err_not_grant_L_N_sig_or_empty_N_not_grant_L_N => err_not_grant_L_N_sig_or_empty_N_not_grant_L_N ,
            err_grant_L_E_sig_not_empty_E_grant_L_E => err_grant_L_E_sig_not_empty_E_grant_L_E ,
            err_not_grant_L_E_sig_or_empty_E_not_grant_L_E => err_not_grant_L_E_sig_or_empty_E_not_grant_L_E ,
            err_grant_L_W_sig_not_empty_W_grant_L_W => err_grant_L_W_sig_not_empty_W_grant_L_W ,
            err_not_grant_L_W_sig_or_empty_W_not_grant_L_W => err_not_grant_L_W_sig_or_empty_W_not_grant_L_W ,
            err_grant_L_S_sig_not_empty_S_grant_L_S => err_grant_L_S_sig_not_empty_S_grant_L_S ,
            err_not_grant_L_S_sig_or_empty_S_not_grant_L_S => err_not_grant_L_S_sig_or_empty_S_not_grant_L_S ,
            err_grant_L_L_sig_not_empty_L_grant_L_L => err_grant_L_L_sig_not_empty_L_grant_L_L ,
            err_not_grant_L_L_sig_or_empty_L_not_grant_L_L => err_not_grant_L_L_sig_or_empty_L_not_grant_L_L ,

            err_grant_signals_not_empty_grant_N => err_grant_signals_not_empty_grant_N ,
            err_not_grant_signals_empty_not_grant_N => err_not_grant_signals_empty_not_grant_N ,
            err_grant_signals_not_empty_grant_E => err_grant_signals_not_empty_grant_E ,
            err_not_grant_signals_empty_not_grant_E => err_not_grant_signals_empty_not_grant_E ,
            err_grant_signals_not_empty_grant_W => err_grant_signals_not_empty_grant_W ,
            err_not_grant_signals_empty_not_grant_W => err_not_grant_signals_empty_not_grant_W ,
            err_grant_signals_not_empty_grant_S => err_grant_signals_not_empty_grant_S ,
            err_not_grant_signals_empty_not_grant_S => err_not_grant_signals_empty_not_grant_S ,
            err_grant_signals_not_empty_grant_L => err_grant_signals_not_empty_grant_L ,
            err_not_grant_signals_empty_not_grant_L => err_not_grant_signals_empty_not_grant_L ,

            err_grants_valid_not_match => err_grants_valid_not_match ,

            -- Allocator credit counter logic checker outputs
            err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal  => err_credit_in_N_grant_N_credit_counter_N_in_credit_counter_N_out_equal ,
            err_credit_in_N_credit_counter_N_out_increment  => err_credit_in_N_credit_counter_N_out_increment ,
            err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change  => err_not_credit_in_N_credit_counter_N_out_max_credit_counter_N_in_not_change ,
            err_grant_N_credit_counter_N_out_decrement  => err_grant_N_credit_counter_N_out_decrement ,
            err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change         => err_not_grant_N_or_credit_counter_N_out_zero_credit_counter_N_in_not_change        ,
            err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal  => err_not_credit_in_N_not_grant_N_credit_counter_N_in_credit_counter_N_out_equal ,

            err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal  => err_credit_in_E_grant_E_credit_counter_E_in_credit_counter_E_out_equal ,
            err_credit_in_E_credit_counter_E_out_increment  => err_credit_in_E_credit_counter_E_out_increment ,
            err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change  => err_not_credit_in_E_credit_counter_E_out_max_credit_counter_E_in_not_change ,
            err_grant_E_credit_counter_E_out_decrement  => err_grant_E_credit_counter_E_out_decrement ,
            err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change         => err_not_grant_E_or_credit_counter_E_out_zero_credit_counter_E_in_not_change        ,
            err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal  => err_not_credit_in_E_not_grant_E_credit_counter_E_in_credit_counter_E_out_equal ,

            err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal  => err_credit_in_W_grant_W_credit_counter_W_in_credit_counter_W_out_equal ,
            err_credit_in_W_credit_counter_W_out_increment  => err_credit_in_W_credit_counter_W_out_increment ,
            err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change  => err_not_credit_in_W_credit_counter_W_out_max_credit_counter_W_in_not_change ,
            err_grant_W_credit_counter_W_out_decrement  => err_grant_W_credit_counter_W_out_decrement ,
            err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change         => err_not_grant_W_or_credit_counter_W_out_zero_credit_counter_W_in_not_change        ,
            err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal  => err_not_credit_in_W_not_grant_W_credit_counter_W_in_credit_counter_W_out_equal ,

            err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal  => err_credit_in_S_grant_S_credit_counter_S_in_credit_counter_S_out_equal ,
            err_credit_in_S_credit_counter_S_out_increment  => err_credit_in_S_credit_counter_S_out_increment ,
            err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change  => err_not_credit_in_S_credit_counter_S_out_max_credit_counter_S_in_not_change ,
            err_grant_S_credit_counter_S_out_decrement  => err_grant_S_credit_counter_S_out_decrement ,
            err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change         => err_not_grant_S_or_credit_counter_S_out_zero_credit_counter_S_in_not_change        ,
            err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal  => err_not_credit_in_S_not_grant_S_credit_counter_S_in_credit_counter_S_out_equal ,

            err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal  => err_credit_in_L_grant_L_credit_counter_L_in_credit_counter_L_out_equal ,
            err_credit_in_L_credit_counter_L_out_increment  => err_credit_in_L_credit_counter_L_out_increment ,
            err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change  => err_not_credit_in_L_credit_counter_L_out_max_credit_counter_L_in_not_change ,
            err_grant_L_credit_counter_L_out_decrement  => err_grant_L_credit_counter_L_out_decrement ,
            err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change  => err_not_grant_L_or_credit_counter_L_out_zero_credit_counter_L_in_not_change ,
            err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal  => err_not_credit_in_L_not_grant_L_credit_counter_L_in_credit_counter_L_out_equal ,

               -- North Arbiter_in Checker outputs
              N_err_Requests_state_in_state_not_equal => N_err_Requests_state_in_state_not_equal,

              N_err_IDLE_Req_N =>    N_err_IDLE_Req_N,
              N_err_IDLE_grant_N =>  N_err_IDLE_grant_N,
              N_err_North_Req_N =>   N_err_North_Req_N,
              N_err_North_grant_N => N_err_North_grant_N,
              N_err_East_Req_E =>    N_err_East_Req_E,
              N_err_East_grant_E =>  N_err_East_grant_E,
              N_err_West_Req_W =>    N_err_West_Req_W,
              N_err_West_grant_W =>  N_err_West_grant_W,
              N_err_South_Req_S =>   N_err_South_Req_S,
              N_err_South_grant_S => N_err_South_grant_S,
              N_err_Local_Req_L =>   N_err_Local_Req_L,
              N_err_Local_grant_L => N_err_Local_grant_L,

              N_err_IDLE_Req_E => N_err_IDLE_Req_E,
              N_err_IDLE_grant_E => N_err_IDLE_grant_E,
              N_err_North_Req_E => N_err_North_Req_E,
              N_err_North_grant_E => N_err_North_grant_E,
              N_err_East_Req_W => N_err_East_Req_W,
              N_err_East_grant_W => N_err_East_grant_W,
              N_err_West_Req_S => N_err_West_Req_S,
              N_err_West_grant_S => N_err_West_grant_S,
              N_err_South_Req_L => N_err_South_Req_L,
              N_err_South_grant_L => N_err_South_grant_L,
              N_err_Local_Req_N => N_err_Local_Req_N,
              N_err_Local_grant_N => N_err_Local_grant_N,

              N_err_IDLE_Req_W => N_err_IDLE_Req_W,
              N_err_IDLE_grant_W => N_err_IDLE_grant_W,
              N_err_North_Req_W => N_err_North_Req_W,
              N_err_North_grant_W => N_err_North_grant_W,
              N_err_East_Req_S => N_err_East_Req_S,
              N_err_East_grant_S => N_err_East_grant_S,
              N_err_West_Req_L => N_err_West_Req_L,
              N_err_West_grant_L => N_err_West_grant_L,
              N_err_South_Req_N => N_err_South_Req_N,
              N_err_South_grant_N => N_err_South_grant_N,
              N_err_Local_Req_E => N_err_Local_Req_E,
              N_err_Local_grant_E => N_err_Local_grant_E,

              N_err_IDLE_Req_S => N_err_IDLE_Req_S,
              N_err_IDLE_grant_S => N_err_IDLE_grant_S,
              N_err_North_Req_S => N_err_North_Req_S,
              N_err_North_grant_S => N_err_North_grant_S,
              N_err_East_Req_L => N_err_East_Req_L,
              N_err_East_grant_L => N_err_East_grant_L,
              N_err_West_Req_N => N_err_West_Req_N,
              N_err_West_grant_N => N_err_West_grant_N,
              N_err_South_Req_E => N_err_South_Req_E,
              N_err_South_grant_E => N_err_South_grant_E,
              N_err_Local_Req_W => N_err_Local_Req_W,
              N_err_Local_grant_W => N_err_Local_grant_W,

              N_err_IDLE_Req_L => N_err_IDLE_Req_L,
              N_err_IDLE_grant_L => N_err_IDLE_grant_L,
              N_err_North_Req_L => N_err_North_Req_L,
              N_err_North_grant_L => N_err_North_grant_L,
              N_err_East_Req_N => N_err_East_Req_N,
              N_err_East_grant_N => N_err_East_grant_N,
              N_err_West_Req_E => N_err_West_Req_E,
              N_err_West_grant_E => N_err_West_grant_E,
              N_err_South_Req_W => N_err_South_Req_W,
              N_err_South_grant_W => N_err_South_grant_W,
              N_err_Local_Req_S => N_err_Local_Req_S,
              N_err_Local_grant_S => N_err_Local_grant_S,

              N_err_state_in_onehot   => N_err_arbiter_state_in_onehot,
              N_err_no_request_grants => N_err_no_request_grants,
              N_err_request_no_grants => N_err_request_no_grants,

              N_err_no_Req_N_grant_N => N_err_no_Req_N_grant_N,
              N_err_no_Req_E_grant_E => N_err_no_Req_E_grant_E,
              N_err_no_Req_W_grant_W => N_err_no_Req_W_grant_W,
              N_err_no_Req_S_grant_S => N_err_no_Req_S_grant_S,
              N_err_no_Req_L_grant_L => N_err_no_Req_L_grant_L,

               -- East Arbiter_in Checker outputs
              E_err_Requests_state_in_state_not_equal => E_err_Requests_state_in_state_not_equal,

              E_err_IDLE_Req_N =>    E_err_IDLE_Req_N,
              E_err_IDLE_grant_N =>  E_err_IDLE_grant_N,
              E_err_North_Req_N =>   E_err_North_Req_N,
              E_err_North_grant_N => E_err_North_grant_N,
              E_err_East_Req_E =>    E_err_East_Req_E,
              E_err_East_grant_E =>  E_err_East_grant_E,
              E_err_West_Req_W =>    E_err_West_Req_W,
              E_err_West_grant_W =>  E_err_West_grant_W,
              E_err_South_Req_S =>   E_err_South_Req_S,
              E_err_South_grant_S => E_err_South_grant_S,
              E_err_Local_Req_L =>   E_err_Local_Req_L,
              E_err_Local_grant_L => E_err_Local_grant_L,

              E_err_IDLE_Req_E => E_err_IDLE_Req_E,
              E_err_IDLE_grant_E => E_err_IDLE_grant_E,
              E_err_North_Req_E => E_err_North_Req_E,
              E_err_North_grant_E => E_err_North_grant_E,
              E_err_East_Req_W => E_err_East_Req_W,
              E_err_East_grant_W => E_err_East_grant_W,
              E_err_West_Req_S => E_err_West_Req_S,
              E_err_West_grant_S => E_err_West_grant_S,
              E_err_South_Req_L => E_err_South_Req_L,
              E_err_South_grant_L => E_err_South_grant_L,
              E_err_Local_Req_N => E_err_Local_Req_N,
              E_err_Local_grant_N => E_err_Local_grant_N,

              E_err_IDLE_Req_W => E_err_IDLE_Req_W,
              E_err_IDLE_grant_W => E_err_IDLE_grant_W,
              E_err_North_Req_W => E_err_North_Req_W,
              E_err_North_grant_W => E_err_North_grant_W,
              E_err_East_Req_S => E_err_East_Req_S,
              E_err_East_grant_S => E_err_East_grant_S,
              E_err_West_Req_L => E_err_West_Req_L,
              E_err_West_grant_L => E_err_West_grant_L,
              E_err_South_Req_N => E_err_South_Req_N,
              E_err_South_grant_N => E_err_South_grant_N,
              E_err_Local_Req_E => E_err_Local_Req_E,
              E_err_Local_grant_E => E_err_Local_grant_E,

              E_err_IDLE_Req_S => E_err_IDLE_Req_S,
              E_err_IDLE_grant_S => E_err_IDLE_grant_S,
              E_err_North_Req_S => E_err_North_Req_S,
              E_err_North_grant_S => E_err_North_grant_S,
              E_err_East_Req_L => E_err_East_Req_L,
              E_err_East_grant_L => E_err_East_grant_L,
              E_err_West_Req_N => E_err_West_Req_N,
              E_err_West_grant_N => E_err_West_grant_N,
              E_err_South_Req_E => E_err_South_Req_E,
              E_err_South_grant_E => E_err_South_grant_E,
              E_err_Local_Req_W => E_err_Local_Req_W,
              E_err_Local_grant_W => E_err_Local_grant_W,

              E_err_IDLE_Req_L => E_err_IDLE_Req_L,
              E_err_IDLE_grant_L => E_err_IDLE_grant_L,
              E_err_North_Req_L => E_err_North_Req_L,
              E_err_North_grant_L => E_err_North_grant_L,
              E_err_East_Req_N => E_err_East_Req_N,
              E_err_East_grant_N => E_err_East_grant_N,
              E_err_West_Req_E => E_err_West_Req_E,
              E_err_West_grant_E => E_err_West_grant_E,
              E_err_South_Req_W => E_err_South_Req_W,
              E_err_South_grant_W => E_err_South_grant_W,
              E_err_Local_Req_S => E_err_Local_Req_S,
              E_err_Local_grant_S => E_err_Local_grant_S,

              E_err_state_in_onehot   => E_err_arbiter_state_in_onehot,
              E_err_no_request_grants => E_err_no_request_grants,
              E_err_request_no_grants => E_err_request_no_grants,

              E_err_no_Req_N_grant_N => E_err_no_Req_N_grant_N,
              E_err_no_Req_E_grant_E => E_err_no_Req_E_grant_E,
              E_err_no_Req_W_grant_W => E_err_no_Req_W_grant_W,
              E_err_no_Req_S_grant_S => E_err_no_Req_S_grant_S,
              E_err_no_Req_L_grant_L => E_err_no_Req_L_grant_L,

               -- West Arbiter_in Checker outputs
              W_err_Requests_state_in_state_not_equal => W_err_Requests_state_in_state_not_equal,

              W_err_IDLE_Req_N =>    W_err_IDLE_Req_N,
              W_err_IDLE_grant_N =>  W_err_IDLE_grant_N,
              W_err_North_Req_N =>   W_err_North_Req_N,
              W_err_North_grant_N => W_err_North_grant_N,
              W_err_East_Req_E =>    W_err_East_Req_E,
              W_err_East_grant_E =>  W_err_East_grant_E,
              W_err_West_Req_W =>    W_err_West_Req_W,
              W_err_West_grant_W =>  W_err_West_grant_W,
              W_err_South_Req_S =>   W_err_South_Req_S,
              W_err_South_grant_S => W_err_South_grant_S,
              W_err_Local_Req_L =>   W_err_Local_Req_L,
              W_err_Local_grant_L => W_err_Local_grant_L,

              W_err_IDLE_Req_E => W_err_IDLE_Req_E,
              W_err_IDLE_grant_E => W_err_IDLE_grant_E,
              W_err_North_Req_E => W_err_North_Req_E,
              W_err_North_grant_E => W_err_North_grant_E,
              W_err_East_Req_W => W_err_East_Req_W,
              W_err_East_grant_W => W_err_East_grant_W,
              W_err_West_Req_S => W_err_West_Req_S,
              W_err_West_grant_S => W_err_West_grant_S,
              W_err_South_Req_L => W_err_South_Req_L,
              W_err_South_grant_L => W_err_South_grant_L,
              W_err_Local_Req_N => W_err_Local_Req_N,
              W_err_Local_grant_N => W_err_Local_grant_N,

              W_err_IDLE_Req_W => W_err_IDLE_Req_W,
              W_err_IDLE_grant_W => W_err_IDLE_grant_W,
              W_err_North_Req_W => W_err_North_Req_W,
              W_err_North_grant_W => W_err_North_grant_W,
              W_err_East_Req_S => W_err_East_Req_S,
              W_err_East_grant_S => W_err_East_grant_S,
              W_err_West_Req_L => W_err_West_Req_L,
              W_err_West_grant_L => W_err_West_grant_L,
              W_err_South_Req_N => W_err_South_Req_N,
              W_err_South_grant_N => W_err_South_grant_N,
              W_err_Local_Req_E => W_err_Local_Req_E,
              W_err_Local_grant_E => W_err_Local_grant_E,

              W_err_IDLE_Req_S => W_err_IDLE_Req_S,
              W_err_IDLE_grant_S => W_err_IDLE_grant_S,
              W_err_North_Req_S => W_err_North_Req_S,
              W_err_North_grant_S => W_err_North_grant_S,
              W_err_East_Req_L => W_err_East_Req_L,
              W_err_East_grant_L => W_err_East_grant_L,
              W_err_West_Req_N => W_err_West_Req_N,
              W_err_West_grant_N => W_err_West_grant_N,
              W_err_South_Req_E => W_err_South_Req_E,
              W_err_South_grant_E => W_err_South_grant_E,
              W_err_Local_Req_W => W_err_Local_Req_W,
              W_err_Local_grant_W => W_err_Local_grant_W,

              W_err_IDLE_Req_L => W_err_IDLE_Req_L,
              W_err_IDLE_grant_L => W_err_IDLE_grant_L,
              W_err_North_Req_L => W_err_North_Req_L,
              W_err_North_grant_L => W_err_North_grant_L,
              W_err_East_Req_N => W_err_East_Req_N,
              W_err_East_grant_N => W_err_East_grant_N,
              W_err_West_Req_E => W_err_West_Req_E,
              W_err_West_grant_E => W_err_West_grant_E,
              W_err_South_Req_W => W_err_South_Req_W,
              W_err_South_grant_W => W_err_South_grant_W,
              W_err_Local_Req_S => W_err_Local_Req_S,
              W_err_Local_grant_S => W_err_Local_grant_S,

              W_err_state_in_onehot   => W_err_arbiter_state_in_onehot,
              W_err_no_request_grants => W_err_no_request_grants,
              W_err_request_no_grants => W_err_request_no_grants,

              W_err_no_Req_N_grant_N => W_err_no_Req_N_grant_N,
              W_err_no_Req_E_grant_E => W_err_no_Req_E_grant_E,
              W_err_no_Req_W_grant_W => W_err_no_Req_W_grant_W,
              W_err_no_Req_S_grant_S => W_err_no_Req_S_grant_S,
              W_err_no_Req_L_grant_L => W_err_no_Req_L_grant_L,

               -- South Arbiter_in Checker outputs
              S_err_Requests_state_in_state_not_equal => S_err_Requests_state_in_state_not_equal,

              S_err_IDLE_Req_N =>    S_err_IDLE_Req_N,
              S_err_IDLE_grant_N =>  S_err_IDLE_grant_N,
              S_err_North_Req_N =>   S_err_North_Req_N,
              S_err_North_grant_N => S_err_North_grant_N,
              S_err_East_Req_E =>    S_err_East_Req_E,
              S_err_East_grant_E =>  S_err_East_grant_E,
              S_err_West_Req_W =>    S_err_West_Req_W,
              S_err_West_grant_W =>  S_err_West_grant_W,
              S_err_South_Req_S =>   S_err_South_Req_S,
              S_err_South_grant_S => S_err_South_grant_S,
              S_err_Local_Req_L =>   S_err_Local_Req_L,
              S_err_Local_grant_L => S_err_Local_grant_L,

              S_err_IDLE_Req_E => S_err_IDLE_Req_E,
              S_err_IDLE_grant_E => S_err_IDLE_grant_E,
              S_err_North_Req_E => S_err_North_Req_E,
              S_err_North_grant_E => S_err_North_grant_E,
              S_err_East_Req_W => S_err_East_Req_W,
              S_err_East_grant_W => S_err_East_grant_W,
              S_err_West_Req_S => S_err_West_Req_S,
              S_err_West_grant_S => S_err_West_grant_S,
              S_err_South_Req_L => S_err_South_Req_L,
              S_err_South_grant_L => S_err_South_grant_L,
              S_err_Local_Req_N => S_err_Local_Req_N,
              S_err_Local_grant_N => S_err_Local_grant_N,

              S_err_IDLE_Req_W => S_err_IDLE_Req_W,
              S_err_IDLE_grant_W => S_err_IDLE_grant_W,
              S_err_North_Req_W => S_err_North_Req_W,
              S_err_North_grant_W => S_err_North_grant_W,
              S_err_East_Req_S => S_err_East_Req_S,
              S_err_East_grant_S => S_err_East_grant_S,
              S_err_West_Req_L => S_err_West_Req_L,
              S_err_West_grant_L => S_err_West_grant_L,
              S_err_South_Req_N => S_err_South_Req_N,
              S_err_South_grant_N => S_err_South_grant_N,
              S_err_Local_Req_E => S_err_Local_Req_E,
              S_err_Local_grant_E => S_err_Local_grant_E,

              S_err_IDLE_Req_S => S_err_IDLE_Req_S,
              S_err_IDLE_grant_S => S_err_IDLE_grant_S,
              S_err_North_Req_S => S_err_North_Req_S,
              S_err_North_grant_S => S_err_North_grant_S,
              S_err_East_Req_L => S_err_East_Req_L,
              S_err_East_grant_L => S_err_East_grant_L,
              S_err_West_Req_N => S_err_West_Req_N,
              S_err_West_grant_N => S_err_West_grant_N,
              S_err_South_Req_E => S_err_South_Req_E,
              S_err_South_grant_E => S_err_South_grant_E,
              S_err_Local_Req_W => S_err_Local_Req_W,
              S_err_Local_grant_W => S_err_Local_grant_W,

              S_err_IDLE_Req_L => S_err_IDLE_Req_L,
              S_err_IDLE_grant_L => S_err_IDLE_grant_L,
              S_err_North_Req_L => S_err_North_Req_L,
              S_err_North_grant_L => S_err_North_grant_L,
              S_err_East_Req_N => S_err_East_Req_N,
              S_err_East_grant_N => S_err_East_grant_N,
              S_err_West_Req_E => S_err_West_Req_E,
              S_err_West_grant_E => S_err_West_grant_E,
              S_err_South_Req_W => S_err_South_Req_W,
              S_err_South_grant_W => S_err_South_grant_W,
              S_err_Local_Req_S => S_err_Local_Req_S,
              S_err_Local_grant_S => S_err_Local_grant_S,

              S_err_state_in_onehot   => S_err_arbiter_state_in_onehot,
              S_err_no_request_grants => S_err_no_request_grants,
              S_err_request_no_grants => S_err_request_no_grants,

              S_err_no_Req_N_grant_N => S_err_no_Req_N_grant_N,
              S_err_no_Req_E_grant_E => S_err_no_Req_E_grant_E,
              S_err_no_Req_W_grant_W => S_err_no_Req_W_grant_W,
              S_err_no_Req_S_grant_S => S_err_no_Req_S_grant_S,
              S_err_no_Req_L_grant_L => S_err_no_Req_L_grant_L,

               -- Local Arbiter_in Checker outputs
              L_err_Requests_state_in_state_not_equal => L_err_Requests_state_in_state_not_equal,

              L_err_IDLE_Req_N =>    L_err_IDLE_Req_N,
              L_err_IDLE_grant_N =>  L_err_IDLE_grant_N,
              L_err_North_Req_N =>   L_err_North_Req_N,
              L_err_North_grant_N => L_err_North_grant_N,
              L_err_East_Req_E =>    L_err_East_Req_E,
              L_err_East_grant_E =>  L_err_East_grant_E,
              L_err_West_Req_W =>    L_err_West_Req_W,
              L_err_West_grant_W =>  L_err_West_grant_W,
              L_err_South_Req_S =>   L_err_South_Req_S,
              L_err_South_grant_S => L_err_South_grant_S,
              L_err_Local_Req_L =>   L_err_Local_Req_L,
              L_err_Local_grant_L => L_err_Local_grant_L,

              L_err_IDLE_Req_E => L_err_IDLE_Req_E,
              L_err_IDLE_grant_E => L_err_IDLE_grant_E,
              L_err_North_Req_E => L_err_North_Req_E,
              L_err_North_grant_E => L_err_North_grant_E,
              L_err_East_Req_W => L_err_East_Req_W,
              L_err_East_grant_W => L_err_East_grant_W,
              L_err_West_Req_S => L_err_West_Req_S,
              L_err_West_grant_S => L_err_West_grant_S,
              L_err_South_Req_L => L_err_South_Req_L,
              L_err_South_grant_L => L_err_South_grant_L,
              L_err_Local_Req_N => L_err_Local_Req_N,
              L_err_Local_grant_N => L_err_Local_grant_N,

              L_err_IDLE_Req_W => L_err_IDLE_Req_W,
              L_err_IDLE_grant_W => L_err_IDLE_grant_W,
              L_err_North_Req_W => L_err_North_Req_W,
              L_err_North_grant_W => L_err_North_grant_W,
              L_err_East_Req_S => L_err_East_Req_S,
              L_err_East_grant_S => L_err_East_grant_S,
              L_err_West_Req_L => L_err_West_Req_L,
              L_err_West_grant_L => L_err_West_grant_L,
              L_err_South_Req_N => L_err_South_Req_N,
              L_err_South_grant_N => L_err_South_grant_N,
              L_err_Local_Req_E => L_err_Local_Req_E,
              L_err_Local_grant_E => L_err_Local_grant_E,

              L_err_IDLE_Req_S => L_err_IDLE_Req_S,
              L_err_IDLE_grant_S => L_err_IDLE_grant_S,
              L_err_North_Req_S => L_err_North_Req_S,
              L_err_North_grant_S => L_err_North_grant_S,
              L_err_East_Req_L => L_err_East_Req_L,
              L_err_East_grant_L => L_err_East_grant_L,
              L_err_West_Req_N => L_err_West_Req_N,
              L_err_West_grant_N => L_err_West_grant_N,
              L_err_South_Req_E => L_err_South_Req_E,
              L_err_South_grant_E => L_err_South_grant_E,
              L_err_Local_Req_W => L_err_Local_Req_W,
              L_err_Local_grant_W => L_err_Local_grant_W,

              L_err_IDLE_Req_L => L_err_IDLE_Req_L,
              L_err_IDLE_grant_L => L_err_IDLE_grant_L,
              L_err_North_Req_L => L_err_North_Req_L,
              L_err_North_grant_L => L_err_North_grant_L,
              L_err_East_Req_N => L_err_East_Req_N,
              L_err_East_grant_N => L_err_East_grant_N,
              L_err_West_Req_E => L_err_West_Req_E,
              L_err_West_grant_E => L_err_West_grant_E,
              L_err_South_Req_W => L_err_South_Req_W,
              L_err_South_grant_W => L_err_South_grant_W,
              L_err_Local_Req_S => L_err_Local_Req_S,
              L_err_Local_grant_S => L_err_Local_grant_S,

              L_err_state_in_onehot   => L_err_arbiter_state_in_onehot,
              L_err_no_request_grants => L_err_no_request_grants,
              L_err_request_no_grants => L_err_request_no_grants,

              L_err_no_Req_N_grant_N => L_err_no_Req_N_grant_N,
              L_err_no_Req_E_grant_E => L_err_no_Req_E_grant_E,
              L_err_no_Req_W_grant_W => L_err_no_Req_W_grant_W,
              L_err_no_Req_S_grant_S => L_err_no_Req_S_grant_S,
              L_err_no_Req_L_grant_L => L_err_no_Req_L_grant_L,

              -- Arbiter_out checker outputs

            -- North Arbiter_out checker outputs
            N_arbiter_out_err_Requests_state_in_state_not_equal => N_arbiter_out_err_Requests_state_in_state_not_equal,

            N_err_IDLE_req_X_N => N_err_IDLE_req_X_N,
            N_err_North_req_X_N => N_err_North_req_X_N,
            N_err_North_credit_not_zero_req_X_N_grant_N => N_err_North_credit_not_zero_req_X_N_grant_N,
            N_err_North_credit_zero_or_not_req_X_N_not_grant_N => N_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            N_err_East_req_X_E => N_err_East_req_X_E,
            N_err_East_credit_not_zero_req_X_E_grant_E => N_err_East_credit_not_zero_req_X_E_grant_E,
            N_err_East_credit_zero_or_not_req_X_E_not_grant_E => N_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            N_err_West_req_X_W => N_err_West_req_X_W,
            N_err_West_credit_not_zero_req_X_W_grant_W => N_err_West_credit_not_zero_req_X_W_grant_W,
            N_err_West_credit_zero_or_not_req_X_W_not_grant_W => N_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            N_err_South_req_X_S => N_err_South_req_X_S,
            N_err_South_credit_not_zero_req_X_S_grant_S => N_err_South_credit_not_zero_req_X_S_grant_S,
            N_err_South_credit_zero_or_not_req_X_S_not_grant_S => N_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            N_err_Local_req_X_L => N_err_Local_req_X_L,
            N_err_Local_credit_not_zero_req_X_L_grant_L => N_err_Local_credit_not_zero_req_X_L_grant_L,
            N_err_Local_credit_zero_or_not_req_X_L_not_grant_L => N_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            N_err_IDLE_req_X_E => N_err_IDLE_req_X_E,
            N_err_North_req_X_E => N_err_North_req_X_E,
            N_err_East_req_X_W => N_err_East_req_X_W,
            N_err_West_req_X_S => N_err_West_req_X_S,
            N_err_South_req_X_L => N_err_South_req_X_L,
            N_err_Local_req_X_N => N_err_Local_req_X_N,

            N_err_IDLE_req_X_W => N_err_IDLE_req_X_W,
            N_err_North_req_X_W => N_err_North_req_X_W,
            N_err_East_req_X_S => N_err_East_req_X_S,
            N_err_West_req_X_L => N_err_West_req_X_L,
            N_err_South_req_X_N => N_err_South_req_X_N,
            N_err_Local_req_X_E => N_err_Local_req_X_E,

            N_err_IDLE_req_X_S => N_err_IDLE_req_X_S,
            N_err_North_req_X_S => N_err_North_req_X_S,
            N_err_East_req_X_L => N_err_East_req_X_L,
            N_err_West_req_X_N => N_err_West_req_X_N,
            N_err_South_req_X_E => N_err_South_req_X_E,
            N_err_Local_req_X_W => N_err_Local_req_X_W,

            N_err_IDLE_req_X_L => N_err_IDLE_req_X_L,
            N_err_North_req_X_L => N_err_North_req_X_L,
            N_err_East_req_X_N => N_err_East_req_X_N,
            N_err_West_req_X_E => N_err_West_req_X_E,
            N_err_South_req_X_W => N_err_South_req_X_W,
            N_err_Local_req_X_S => N_err_Local_req_X_S,

            N_arbiter_out_err_state_in_onehot => N_arbiter_out_err_state_in_onehot,
            N_arbiter_out_err_no_request_grants => N_arbiter_out_err_no_request_grants,
            N_err_request_IDLE_state => N_err_request_IDLE_state,

            N_err_request_IDLE_not_Grants => N_err_request_IDLE_not_Grants,
            N_err_state_North_Invalid_Grant => N_err_state_North_Invalid_Grant,
            N_err_state_East_Invalid_Grant => N_err_state_East_Invalid_Grant,
            N_err_state_West_Invalid_Grant => N_err_state_West_Invalid_Grant,
            N_err_state_South_Invalid_Grant => N_err_state_South_Invalid_Grant,
            N_err_state_Local_Invalid_Grant => N_err_state_Local_Invalid_Grant,
            N_err_Grants_onehot_or_all_zero => N_err_Grants_onehot_or_all_zero,

            -- East Arbiter_out checker outputs
            E_arbiter_out_err_Requests_state_in_state_not_equal => E_arbiter_out_err_Requests_state_in_state_not_equal,

            E_err_IDLE_req_X_N => E_err_IDLE_req_X_N,
            E_err_North_req_X_N => E_err_North_req_X_N,
            E_err_North_credit_not_zero_req_X_N_grant_N => E_err_North_credit_not_zero_req_X_N_grant_N,
            E_err_North_credit_zero_or_not_req_X_N_not_grant_N => E_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            E_err_East_req_X_E => E_err_East_req_X_E,
            E_err_East_credit_not_zero_req_X_E_grant_E => E_err_East_credit_not_zero_req_X_E_grant_E,
            E_err_East_credit_zero_or_not_req_X_E_not_grant_E => E_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            E_err_West_req_X_W => E_err_West_req_X_W,
            E_err_West_credit_not_zero_req_X_W_grant_W => E_err_West_credit_not_zero_req_X_W_grant_W,
            E_err_West_credit_zero_or_not_req_X_W_not_grant_W => E_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            E_err_South_req_X_S => E_err_South_req_X_S,
            E_err_South_credit_not_zero_req_X_S_grant_S => E_err_South_credit_not_zero_req_X_S_grant_S,
            E_err_South_credit_zero_or_not_req_X_S_not_grant_S => E_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            E_err_Local_req_X_L => E_err_Local_req_X_L,
            E_err_Local_credit_not_zero_req_X_L_grant_L => E_err_Local_credit_not_zero_req_X_L_grant_L,
            E_err_Local_credit_zero_or_not_req_X_L_not_grant_L => E_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            E_err_IDLE_req_X_E => E_err_IDLE_req_X_E,
            E_err_North_req_X_E => E_err_North_req_X_E,
            E_err_East_req_X_W => E_err_East_req_X_W,
            E_err_West_req_X_S => E_err_West_req_X_S,
            E_err_South_req_X_L => E_err_South_req_X_L,
            E_err_Local_req_X_N => E_err_Local_req_X_N,

            E_err_IDLE_req_X_W => E_err_IDLE_req_X_W,
            E_err_North_req_X_W => E_err_North_req_X_W,
            E_err_East_req_X_S => E_err_East_req_X_S,
            E_err_West_req_X_L => E_err_West_req_X_L,
            E_err_South_req_X_N => E_err_South_req_X_N,
            E_err_Local_req_X_E => E_err_Local_req_X_E,

            E_err_IDLE_req_X_S => E_err_IDLE_req_X_S,
            E_err_North_req_X_S => E_err_North_req_X_S,
            E_err_East_req_X_L => E_err_East_req_X_L,
            E_err_West_req_X_N => E_err_West_req_X_N,
            E_err_South_req_X_E => E_err_South_req_X_E,
            E_err_Local_req_X_W => E_err_Local_req_X_W,

            E_err_IDLE_req_X_L => E_err_IDLE_req_X_L,
            E_err_North_req_X_L => E_err_North_req_X_L,
            E_err_East_req_X_N => E_err_East_req_X_N,
            E_err_West_req_X_E => E_err_West_req_X_E,
            E_err_South_req_X_W => E_err_South_req_X_W,
            E_err_Local_req_X_S => E_err_Local_req_X_S,

            E_arbiter_out_err_state_in_onehot => E_arbiter_out_err_state_in_onehot,
            E_arbiter_out_err_no_request_grants => E_arbiter_out_err_no_request_grants,
            E_err_request_IDLE_state => E_err_request_IDLE_state,

            E_err_request_IDLE_not_Grants => E_err_request_IDLE_not_Grants,
            E_err_state_North_Invalid_Grant => E_err_state_North_Invalid_Grant,
            E_err_state_East_Invalid_Grant => E_err_state_East_Invalid_Grant,
            E_err_state_West_Invalid_Grant => E_err_state_West_Invalid_Grant,
            E_err_state_South_Invalid_Grant => E_err_state_South_Invalid_Grant,
            E_err_state_Local_Invalid_Grant => E_err_state_Local_Invalid_Grant,
            E_err_Grants_onehot_or_all_zero => E_err_Grants_onehot_or_all_zero,

            -- West Arbiter_out checker outputs
            W_arbiter_out_err_Requests_state_in_state_not_equal => W_arbiter_out_err_Requests_state_in_state_not_equal,

            W_err_IDLE_req_X_N => W_err_IDLE_req_X_N,
            W_err_North_req_X_N => W_err_North_req_X_N,
            W_err_North_credit_not_zero_req_X_N_grant_N => W_err_North_credit_not_zero_req_X_N_grant_N,
            W_err_North_credit_zero_or_not_req_X_N_not_grant_N => W_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            W_err_East_req_X_E => W_err_East_req_X_E,
            W_err_East_credit_not_zero_req_X_E_grant_E => W_err_East_credit_not_zero_req_X_E_grant_E,
            W_err_East_credit_zero_or_not_req_X_E_not_grant_E => W_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            W_err_West_req_X_W => W_err_West_req_X_W,
            W_err_West_credit_not_zero_req_X_W_grant_W => W_err_West_credit_not_zero_req_X_W_grant_W,
            W_err_West_credit_zero_or_not_req_X_W_not_grant_W => W_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            W_err_South_req_X_S => W_err_South_req_X_S,
            W_err_South_credit_not_zero_req_X_S_grant_S => W_err_South_credit_not_zero_req_X_S_grant_S,
            W_err_South_credit_zero_or_not_req_X_S_not_grant_S => W_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            W_err_Local_req_X_L => W_err_Local_req_X_L,
            W_err_Local_credit_not_zero_req_X_L_grant_L => W_err_Local_credit_not_zero_req_X_L_grant_L,
            W_err_Local_credit_zero_or_not_req_X_L_not_grant_L => W_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            W_err_IDLE_req_X_E => W_err_IDLE_req_X_E,
            W_err_North_req_X_E => W_err_North_req_X_E,
            W_err_East_req_X_W => W_err_East_req_X_W,
            W_err_West_req_X_S => W_err_West_req_X_S,
            W_err_South_req_X_L => W_err_South_req_X_L,
            W_err_Local_req_X_N => W_err_Local_req_X_N,

            W_err_IDLE_req_X_W => W_err_IDLE_req_X_W,
            W_err_North_req_X_W => W_err_North_req_X_W,
            W_err_East_req_X_S => W_err_East_req_X_S,
            W_err_West_req_X_L => W_err_West_req_X_L,
            W_err_South_req_X_N => W_err_South_req_X_N,
            W_err_Local_req_X_E => W_err_Local_req_X_E,

            W_err_IDLE_req_X_S => W_err_IDLE_req_X_S,
            W_err_North_req_X_S => W_err_North_req_X_S,
            W_err_East_req_X_L => W_err_East_req_X_L,
            W_err_West_req_X_N => W_err_West_req_X_N,
            W_err_South_req_X_E => W_err_South_req_X_E,
            W_err_Local_req_X_W => W_err_Local_req_X_W,

            W_err_IDLE_req_X_L => W_err_IDLE_req_X_L,
            W_err_North_req_X_L => W_err_North_req_X_L,
            W_err_East_req_X_N => W_err_East_req_X_N,
            W_err_West_req_X_E => W_err_West_req_X_E,
            W_err_South_req_X_W => W_err_South_req_X_W,
            W_err_Local_req_X_S => W_err_Local_req_X_S,

            W_arbiter_out_err_state_in_onehot => W_arbiter_out_err_state_in_onehot,
            W_arbiter_out_err_no_request_grants => W_arbiter_out_err_no_request_grants,
            W_err_request_IDLE_state => W_err_request_IDLE_state,

            W_err_request_IDLE_not_Grants => W_err_request_IDLE_not_Grants,
            W_err_state_North_Invalid_Grant => W_err_state_North_Invalid_Grant,
            W_err_state_East_Invalid_Grant => W_err_state_East_Invalid_Grant,
            W_err_state_West_Invalid_Grant => W_err_state_West_Invalid_Grant,
            W_err_state_South_Invalid_Grant => W_err_state_South_Invalid_Grant,
            W_err_state_Local_Invalid_Grant => W_err_state_Local_Invalid_Grant,
            W_err_Grants_onehot_or_all_zero => W_err_Grants_onehot_or_all_zero,

            -- South Arbiter_out checker outputs
            S_arbiter_out_err_Requests_state_in_state_not_equal => S_arbiter_out_err_Requests_state_in_state_not_equal,

            S_err_IDLE_req_X_N => S_err_IDLE_req_X_N,
            S_err_North_req_X_N => S_err_North_req_X_N,
            S_err_North_credit_not_zero_req_X_N_grant_N => S_err_North_credit_not_zero_req_X_N_grant_N,
            S_err_North_credit_zero_or_not_req_X_N_not_grant_N => S_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            S_err_East_req_X_E => S_err_East_req_X_E,
            S_err_East_credit_not_zero_req_X_E_grant_E => S_err_East_credit_not_zero_req_X_E_grant_E,
            S_err_East_credit_zero_or_not_req_X_E_not_grant_E => S_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            S_err_West_req_X_W => S_err_West_req_X_W,
            S_err_West_credit_not_zero_req_X_W_grant_W => S_err_West_credit_not_zero_req_X_W_grant_W,
            S_err_West_credit_zero_or_not_req_X_W_not_grant_W => S_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            S_err_South_req_X_S => S_err_South_req_X_S,
            S_err_South_credit_not_zero_req_X_S_grant_S => S_err_South_credit_not_zero_req_X_S_grant_S,
            S_err_South_credit_zero_or_not_req_X_S_not_grant_S => S_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            S_err_Local_req_X_L => S_err_Local_req_X_L,
            S_err_Local_credit_not_zero_req_X_L_grant_L => S_err_Local_credit_not_zero_req_X_L_grant_L,
            S_err_Local_credit_zero_or_not_req_X_L_not_grant_L => S_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            S_err_IDLE_req_X_E => S_err_IDLE_req_X_E,
            S_err_North_req_X_E => S_err_North_req_X_E,
            S_err_East_req_X_W => S_err_East_req_X_W,
            S_err_West_req_X_S => S_err_West_req_X_S,
            S_err_South_req_X_L => S_err_South_req_X_L,
            S_err_Local_req_X_N => S_err_Local_req_X_N,

            S_err_IDLE_req_X_W => S_err_IDLE_req_X_W,
            S_err_North_req_X_W => S_err_North_req_X_W,
            S_err_East_req_X_S => S_err_East_req_X_S,
            S_err_West_req_X_L => S_err_West_req_X_L,
            S_err_South_req_X_N => S_err_South_req_X_N,
            S_err_Local_req_X_E => S_err_Local_req_X_E,

            S_err_IDLE_req_X_S => S_err_IDLE_req_X_S,
            S_err_North_req_X_S => S_err_North_req_X_S,
            S_err_East_req_X_L => S_err_East_req_X_L,
            S_err_West_req_X_N => S_err_West_req_X_N,
            S_err_South_req_X_E => S_err_South_req_X_E,
            S_err_Local_req_X_W => S_err_Local_req_X_W,

            S_err_IDLE_req_X_L => S_err_IDLE_req_X_L,
            S_err_North_req_X_L => S_err_North_req_X_L,
            S_err_East_req_X_N => S_err_East_req_X_N,
            S_err_West_req_X_E => S_err_West_req_X_E,
            S_err_South_req_X_W => S_err_South_req_X_W,
            S_err_Local_req_X_S => S_err_Local_req_X_S,

            S_arbiter_out_err_state_in_onehot => S_arbiter_out_err_state_in_onehot,
            S_arbiter_out_err_no_request_grants => S_arbiter_out_err_no_request_grants,
            S_err_request_IDLE_state => S_err_request_IDLE_state,

            S_err_request_IDLE_not_Grants => S_err_request_IDLE_not_Grants,
            S_err_state_North_Invalid_Grant => S_err_state_North_Invalid_Grant,
            S_err_state_East_Invalid_Grant => S_err_state_East_Invalid_Grant,
            S_err_state_West_Invalid_Grant => S_err_state_West_Invalid_Grant,
            S_err_state_South_Invalid_Grant => S_err_state_South_Invalid_Grant,
            S_err_state_Local_Invalid_Grant => S_err_state_Local_Invalid_Grant,
            S_err_Grants_onehot_or_all_zero => S_err_Grants_onehot_or_all_zero,

            -- Local Arbiter_out checker outputs
            L_arbiter_out_err_Requests_state_in_state_not_equal => L_arbiter_out_err_Requests_state_in_state_not_equal,

            L_err_IDLE_req_X_N => L_err_IDLE_req_X_N,
            L_err_North_req_X_N => L_err_North_req_X_N,
            L_err_North_credit_not_zero_req_X_N_grant_N => L_err_North_credit_not_zero_req_X_N_grant_N,
            L_err_North_credit_zero_or_not_req_X_N_not_grant_N => L_err_North_credit_zero_or_not_req_X_N_not_grant_N,
            L_err_East_req_X_E => L_err_East_req_X_E,
            L_err_East_credit_not_zero_req_X_E_grant_E => L_err_East_credit_not_zero_req_X_E_grant_E,
            L_err_East_credit_zero_or_not_req_X_E_not_grant_E => L_err_East_credit_zero_or_not_req_X_E_not_grant_E,
            L_err_West_req_X_W => L_err_West_req_X_W,
            L_err_West_credit_not_zero_req_X_W_grant_W => L_err_West_credit_not_zero_req_X_W_grant_W,
            L_err_West_credit_zero_or_not_req_X_W_not_grant_W => L_err_West_credit_zero_or_not_req_X_W_not_grant_W,
            L_err_South_req_X_S => L_err_South_req_X_S,
            L_err_South_credit_not_zero_req_X_S_grant_S => L_err_South_credit_not_zero_req_X_S_grant_S,
            L_err_South_credit_zero_or_not_req_X_S_not_grant_S => L_err_South_credit_zero_or_not_req_X_S_not_grant_S,
            L_err_Local_req_X_L => L_err_Local_req_X_L,
            L_err_Local_credit_not_zero_req_X_L_grant_L => L_err_Local_credit_not_zero_req_X_L_grant_L,
            L_err_Local_credit_zero_or_not_req_X_L_not_grant_L => L_err_Local_credit_zero_or_not_req_X_L_not_grant_L,

            L_err_IDLE_req_X_E => L_err_IDLE_req_X_E,
            L_err_North_req_X_E => L_err_North_req_X_E,
            L_err_East_req_X_W => L_err_East_req_X_W,
            L_err_West_req_X_S => L_err_West_req_X_S,
            L_err_South_req_X_L => L_err_South_req_X_L,
            L_err_Local_req_X_N => L_err_Local_req_X_N,

            L_err_IDLE_req_X_W => L_err_IDLE_req_X_W,
            L_err_North_req_X_W => L_err_North_req_X_W,
            L_err_East_req_X_S => L_err_East_req_X_S,
            L_err_West_req_X_L => L_err_West_req_X_L,
            L_err_South_req_X_N => L_err_South_req_X_N,
            L_err_Local_req_X_E => L_err_Local_req_X_E,

            L_err_IDLE_req_X_S => L_err_IDLE_req_X_S,
            L_err_North_req_X_S => L_err_North_req_X_S,
            L_err_East_req_X_L => L_err_East_req_X_L,
            L_err_West_req_X_N => L_err_West_req_X_N,
            L_err_South_req_X_E => L_err_South_req_X_E,
            L_err_Local_req_X_W => L_err_Local_req_X_W,

            L_err_IDLE_req_X_L => L_err_IDLE_req_X_L,
            L_err_North_req_X_L => L_err_North_req_X_L,
            L_err_East_req_X_N => L_err_East_req_X_N,
            L_err_West_req_X_E => L_err_West_req_X_E,
            L_err_South_req_X_W => L_err_South_req_X_W,
            L_err_Local_req_X_S => L_err_Local_req_X_S,

            L_arbiter_out_err_state_in_onehot => L_arbiter_out_err_state_in_onehot,
            L_arbiter_out_err_no_request_grants => L_arbiter_out_err_no_request_grants,
            L_err_request_IDLE_state => L_err_request_IDLE_state,

            L_err_request_IDLE_not_Grants => L_err_request_IDLE_not_Grants,
            L_err_state_North_Invalid_Grant => L_err_state_North_Invalid_Grant,
            L_err_state_East_Invalid_Grant => L_err_state_East_Invalid_Grant,
            L_err_state_West_Invalid_Grant => L_err_state_West_Invalid_Grant,
            L_err_state_South_Invalid_Grant => L_err_state_South_Invalid_Grant,
            L_err_state_Local_Invalid_Grant => L_err_state_Local_Invalid_Grant,
            L_err_Grants_onehot_or_all_zero => L_err_Grants_onehot_or_all_zero
          );

------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
-- all the Xbar select_signals

Xbar_sel_N <= '0' & Grant_NE & Grant_NW & Grant_NS & Grant_NL;
Xbar_sel_E <= Grant_EN & '0' & Grant_EW & Grant_ES & Grant_EL;
Xbar_sel_W <= Grant_WN & Grant_WE & '0' & Grant_WS & Grant_WL;
Xbar_sel_S <= Grant_SN & Grant_SE & Grant_SW & '0' & Grant_SL;
Xbar_sel_L <= Grant_LN & Grant_LE & Grant_LW & Grant_LS & '0';


------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
 -- all the Xbars
GEN_XABR: for i in range (0 to ) generate
    XBAR_X: XBAR generic map (DATA_WIDTH  => DATA_WIDTH)
    PORT MAP (North_in => FIFO_D_out_N, East_in => FIFO_D_out_E, West_in => FIFO_D_out_W, South_in => FIFO_D_out_S, Local_in => FIFO_D_out_L,
              sel => Xbar_sel_N,  Data_out=> TX_N);

end generate GEN_XABR;

XBAR_N: XBAR generic map (DATA_WIDTH  => DATA_WIDTH)
   PORT MAP (North_in => FIFO_D_out_N, East_in => FIFO_D_out_E, West_in => FIFO_D_out_W, South_in => FIFO_D_out_S, Local_in => FIFO_D_out_L,
        sel => Xbar_sel_N,  Data_out=> TX_N);
XBAR_E: XBAR generic map (DATA_WIDTH  => DATA_WIDTH)
   PORT MAP (North_in => FIFO_D_out_N, East_in => FIFO_D_out_E, West_in => FIFO_D_out_W, South_in => FIFO_D_out_S, Local_in => FIFO_D_out_L,
        sel => Xbar_sel_E,  Data_out=> TX_E);
XBAR_W: XBAR generic map (DATA_WIDTH  => DATA_WIDTH)
   PORT MAP (North_in => FIFO_D_out_N, East_in => FIFO_D_out_E, West_in => FIFO_D_out_W, South_in => FIFO_D_out_S, Local_in => FIFO_D_out_L,
        sel => Xbar_sel_W,  Data_out=> TX_W);
XBAR_S: XBAR generic map (DATA_WIDTH  => DATA_WIDTH)
   PORT MAP (North_in => FIFO_D_out_N, East_in => FIFO_D_out_E, West_in => FIFO_D_out_W, South_in => FIFO_D_out_S, Local_in => FIFO_D_out_L,
        sel => Xbar_sel_S,  Data_out=> TX_S);
XBAR_L: XBAR generic map (DATA_WIDTH  => DATA_WIDTH)
   PORT MAP (North_in => FIFO_D_out_N, East_in => FIFO_D_out_E, West_in => FIFO_D_out_W, South_in => FIFO_D_out_S, Local_in => FIFO_D_out_L,
        sel => Xbar_sel_L,  Data_out=> TX_L);

end;
