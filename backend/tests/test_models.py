"""Tests for ORM models that don't require a live database."""

from app.models import Building, Edge, Floor, Node, User, UserProfile


def test_models_expose_expected_tables() -> None:
    assert Building.__tablename__ == "buildings"
    assert Floor.__tablename__ == "floors"
    assert Node.__tablename__ == "nodes"
    assert Edge.__tablename__ == "graph_edges"
    assert User.__tablename__ == "users"
    assert UserProfile.__tablename__ == "user_profiles"


def test_edge_defaults_compile_to_false() -> None:
    # Client-side defaults apply at insert time, not construction.
    column = Edge.__table__.c.temporary_blockage
    assert column.default is not None
    assert column.default.arg is False


def test_address_table_is_spatial() -> None:
    # Node positions and building geolocations are PostGIS POINT columns.
    node_position = Node.__table__.c.position
    assert node_position.type.geometry_type == "POINT"

    building_location = Building.__table__.c.geolocation
    assert building_location.type.geometry_type == "POINT"


def test_required_columns_are_non_nullable() -> None:
    assert not Edge.__table__.c.source_node_id.nullable
    assert not Edge.__table__.c.target_node_id.nullable
    assert not Node.__table__.c.node_type.nullable
    assert not User.__table__.c.device_id.nullable