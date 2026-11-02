import 'package:flutter_test/flutter_test.dart';
import 'package:cycling_coach/src/core/geo_utils.dart';
import 'package:cycling_coach/src/core/gpx.dart';
import 'package:cycling_coach/src/models/models.dart';

const _sampleGpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Panitia" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata><name>Audax 200K</name></metadata>
  <trk>
    <name>Rute Resmi Audax</name>
    <trkseg>
      <trkpt lat="-6.2000" lon="106.8000">
        <ele>10.5</ele>
        <time>2026-01-01T00:00:00Z</time>
      </trkpt>
      <trkpt lat="-6.2010" lon="106.8010">
        <ele>12.0</ele>
        <time>2026-01-01T00:05:00Z</time>
      </trkpt>
      <trkpt lat="-6.2020" lon="106.8020">
        <ele>15.0</ele>
        <time>2026-01-01T00:10:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>''';

void main() {
  test('parse trkpt: nama track, elevasi, dan waktu', () {
    final track = parseGpxText(_sampleGpx);
    expect(track.name, 'Rute Resmi Audax');
    expect(track.points.length, 3);
    expect(track.points.first.lat, closeTo(-6.2, 1e-9));
    expect(track.points.first.lng, closeTo(106.8, 1e-9));
    expect(track.points.first.ele, closeTo(10.5, 1e-9));
    expect(
      track.points.first.t,
      DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
    );
    expect(track.segmentCount, 1);
  });

  test('dukung tag ber-namespace + kutip tunggal + self-closing', () {
    const xml = '''<gpx:gpx xmlns:gpx="http://www.topografix.com/GPX/1/1">
      <gpx:trk><gpx:name>Rute Panitia</gpx:name><gpx:trkseg>
        <gpx:trkpt lat='-6.2' lon='106.8'/><gpx:trkpt lat='-6.3' lon='106.9'>
          <gpx:ele>22</gpx:ele>
        </gpx:trkpt>
      </gpx:trkseg></gpx:trk>
    </gpx:gpx>''';
    final track = parseGpxText(xml);
    expect(track.name, 'Rute Panitia');
    expect(track.points.length, 2);
    expect(track.points.first.ele, 0); // tanpa <ele>
    expect(track.points.last.ele, 22);
  });

  test('fallback ke rtept bila tidak ada trkpt', () {
    const xml = '''<gpx>
      <rte><name>Rute Alternatif</name>
        <rtept lat="-7.1" lon="110.1"><ele>100</ele></rtept>
        <rtept lat="-7.2" lon="110.2"><ele>120</ele></rtept>
      </rte>
    </gpx>''';
    final track = parseGpxText(xml);
    expect(track.name, 'Rute Alternatif');
    expect(track.points.length, 2);
    expect(track.points.last.ele, 120);
  });

  test('wpt diabaikan bila ada track resmi', () {
    const xml = '''<gpx><wpt lat="1" lon="1"/><wpt lat="2" lon="2"/>
      <trk><trkseg>
        <trkpt lat="-6.2" lon="106.8"/><trkpt lat="-6.3" lon="106.9"/>
      </trkseg></trk></gpx>''';
    final track = parseGpxText(xml);
    expect(track.points.length, 2);
    expect(track.points.first.lat, -6.2);
  });

  test('nama XML entity & CDATA dibaca manusiawi', () {
    const xml = '''<gpx><trk><name><![CDATA[Gowes &amp; Santai]]></name>
      <trkseg>
        <trkpt lat="-6.2" lon="106.8"/><trkpt lat="-6.3" lon="106.9"/>
      </trkseg></trk></gpx>''';
    final track = parseGpxText(xml);
    expect(track.name, 'Gowes & Santai');
  });

  test('fallback name dari nama file bila GPX tanpa nama', () {
    const xml = '''<gpx><trk><trkseg>
      <trkpt lat="-6.2" lon="106.8"/><trkpt lat="-6.3" lon="106.9"/>
    </trkseg></trk></gpx>''';
    final track = parseGpxText(xml, fallbackName: 'route_panitia.gpx');
    expect(track.name, 'route_panitia.gpx');
  });

  test('koordinat rusak & duplikat berurutan dibuang', () {
    const xml = '''<gpx><trk><trkseg>
      <trkpt lat="999" lon="106.8"/>
      <trkpt lat="-6.2" lon="106.8"/>
      <trkpt lat="-6.2" lon="106.8"/>
      <trkpt lat="-6.3" lon="106.9"/>
    </trkseg></trk></gpx>''';
    final track = parseGpxText(xml);
    expect(track.points.length, 2);
  });

  test('bukan GPX / titik kurang dari 2 → GpxException', () {
    expect(() => parseGpxText('hello world'), throwsA(isA<GpxException>()));
    expect(
      () => parseGpxText(
        '<gpx><trk><trkseg><trkpt lat="-6.2" lon="106.8"/></trkseg></trk></gpx>',
      ),
      throwsA(isA<GpxException>()),
    );
  });

  test('roundtrip buildGpx → parseGpxText', () {
    final pts = [
      const GpsPoint(lat: -6.2, lng: 106.8, ele: 10, t: 1000),
      const GpsPoint(lat: -6.21, lng: 106.81, ele: 20, t: 61000),
    ];
    final gpx = buildGpx('Rute & Event <Uji>', pts, DateTime.utc(2026));
    final track = parseGpxText(gpx);
    expect(track.name, 'Rute & Event <Uji>');
    expect(track.points.length, 2);
    expect(track.points.last.ele, closeTo(20, 0.05));
    expect(track.points.last.t, 61000);
  });
}
