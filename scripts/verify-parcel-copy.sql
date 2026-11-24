-- Compare the parcel copy on the new instance with db-dice (checklist 2.3 / 2.4, DIC-3121, DIC-3122).
-- Read-only. Run the same file against both databases and diff the outputs:
--   psql "$OLD" -f scripts/verify-parcel-copy.sql > old.txt
--   psql "$NEW" -f scripts/verify-parcel-copy.sql > new.txt ; diff old.txt new.txt
-- Run it after ANALYZE on the new database: tile output depends on the query plan.
-- Expect NO differences. Tile functions without ORDER BY (address_points, plss_corners) are
-- compared on their sorted features instead of on bytes, because feature order can differ.
\set QUIET on
\pset tuples_only on
\pset format unaligned

select 'rows geo.'||relname||' '||n from (select c.relname, (xpath('/row/c/text()', query_to_xml('select count(*) as c from geo.'||quote_ident(c.relname), false, true, '')))[1]::text::bigint n from pg_class c join pg_namespace s on s.oid=c.relnamespace where s.nspname='geo' and c.relkind in ('r','v') and c.relname not in ('locations','org_locations','parcels_backup')) t order by 1;
select 'rows assessing.'||relname||' '||n from (select c.relname, (xpath('/row/c/text()', query_to_xml('select count(*) as c from assessing.'||quote_ident(c.relname), false, true, '')))[1]::text::bigint n from pg_class c join pg_namespace s on s.oid=c.relnamespace where s.nspname='assessing' and c.relkind in ('r','v')) t order by 1;

select 'geom md5 parcel_geometry '||md5(string_agg(id::text||encode(ST_AsEWKB(geom),'hex'), '' order by id)) from geo.parcel_geometry;
select 'attr md5 parcel_geometry '||md5(string_agg(concat_ws('|',id,parcel_no,county,municipality,acres,area,source_file,loaded_at,legal_description,tax_description,cogo_legs,source,created_at,updated_at,archived_at), E'\n' order by id)) from geo.parcel_geometry;
select 'md5 geo.address_points '||md5(string_agg(a::text, '' order by a.*::text)) from geo.address_points a;
select 'md5 assessing.vbc_parcels '||md5(string_agg(v::text, '' order by v.*::text)) from assessing.vbc_parcels v;
select 'md5 assessing.cass_parcels '||md5(string_agg(v::text, '' order by v.*::text)) from assessing.cass_parcels v;
select 'md5 geo.parcels view '||md5(string_agg(v::text, '' order by v.*::text)) from geo.parcels v;
select 'srid/type '||string_agg(distinct ST_SRID(geom)||' '||GeometryType(geom), ', ') from geo.parcel_geometry;

-- Tiles over the first active parcel: parcel_tiles at z14 and z10, then z12 for the other functions.
with c as (select ST_Centroid(ST_Transform(geom,3857)) g from geo.parcel_geometry where archived_at is null order by id limit 1),
t as (select 14 z, floor((ST_X(g)+20037508.342789244)/(40075016.68557849/16384))::int x, floor((20037508.342789244-ST_Y(g))/(40075016.68557849/16384))::int y from c
      union all select 10, floor((ST_X(g)+20037508.342789244)/(40075016.68557849/1024))::int, floor((20037508.342789244-ST_Y(g))/(40075016.68557849/1024))::int from c)
select 'tile '||z||'/'||x||'/'||y||' parcel_tiles md5='||md5(geo.parcel_tiles(z,x,y))||' bytes='||length(geo.parcel_tiles(z,x,y)) from t order by z;

with c as (select ST_Centroid(ST_Transform(geom,3857)) g from geo.parcel_geometry where archived_at is null order by id limit 1),
t as (select 12 z, floor((ST_X(g)+20037508.342789244)/(40075016.68557849/4096))::int x, floor((20037508.342789244-ST_Y(g))/(40075016.68557849/4096))::int y from c)
select 'z12 '||f||' md5='||coalesce(md5(r),'null')||' bytes='||coalesce(length(r),0) from t, lateral (
  select 'drains' f, geo.drains_tiles(z,x,y) r
  union all select 'parcel_points', geo.parcel_points_tiles(z,x,y)
  union all select 'plss_section_lines', geo.plss_section_lines_tiles(z,x,y)
  union all select 'plss_sections', geo.plss_sections_tiles(z,x,y)
  union all select 'reference_drains', geo.reference_drains_tiles(z,x,y)
  union all select 'reference_roads', geo.reference_roads_tiles(z,x,y)
  union all select 'reference_section_lines', geo.reference_section_lines_tiles(z,x,y)
  union all select 'road_centerlines', geo.road_centerlines_tiles(z,x,y)
  union all select 'section_centers', geo.section_centers_tiles(z,x,y)
  union all select 'subdivisions', geo.subdivisions_tiles(z,x,y)) s order by f;

-- No ORDER BY in these two tile functions: compare the features, sorted, not the bytes.
with c as (select ST_Centroid(ST_Transform(geom,3857)) g from geo.parcel_geometry where archived_at is null order by id limit 1),
t as (select 12 z, floor((ST_X(g)+20037508.342789244)/(40075016.68557849/4096))::int x, floor((20037508.342789244-ST_Y(g))/(40075016.68557849/4096))::int y from c)
select 'z12 address_points features='||count(*)||' md5='||md5(string_agg(concat_ws('|',id,fulladdr,addrnum,addr_sn,addr_st,municipali,pointtype,ST_AsText(ST_AsMVTGeom(ST_Transform(geom,3857),ST_TileEnvelope(z,x,y),4096,64,true))), E'\n' order by id))
from t, geo.address_points where geom && ST_Transform(ST_TileEnvelope(z,x,y),2253) and ST_AsMVTGeom(ST_Transform(geom,3857),ST_TileEnvelope(z,x,y),4096,64,true) is not null;
with c as (select ST_Centroid(ST_Transform(geom,3857)) g from geo.parcel_geometry where archived_at is null order by id limit 1),
t as (select 12 z, floor((ST_X(g)+20037508.342789244)/(40075016.68557849/4096))::int x, floor((20037508.342789244-ST_Y(g))/(40075016.68557849/4096))::int y from c)
select 'z12 plss_corners features='||count(*)||' md5='||md5(string_agg(concat_ws('|',id,town,"range",corner_typ,tr,ST_AsText(ST_AsMVTGeom(ST_Transform(geom,3857),ST_TileEnvelope(z,x,y),4096,64,true))), E'\n' order by id))
from t, geo.plss_corners where geom && ST_Transform(ST_TileEnvelope(z,x,y),2253) and ST_AsMVTGeom(ST_Transform(geom,3857),ST_TileEnvelope(z,x,y),4096,64,true) is not null;
