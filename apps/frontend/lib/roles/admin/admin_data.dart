/// Admin pages are data driven. All numbers and names are design examples.
class Cell {
  const Cell(this.ar, this.en, {this.tone});
  final String ar, en;

  /// ok, warn or bad. Null for plain text.
  final String? tone;
}

Cell c(String a, String e) => Cell(a, e);
Cell s(String v) => Cell(v, v);
Cell ok(String a, String e) => Cell(a, e, tone: 'ok');
Cell wn(String a, String e) => Cell(a, e, tone: 'warn');
Cell bd(String a, String e) => Cell(a, e, tone: 'bad');

sealed class Block {
  const Block();
}

class StatsBlock extends Block {
  const StatsBlock(this.items);

  /// label, value, delta
  final List<(Cell, String, String)> items;
}

class TableBlock extends Block {
  const TableBlock(this.title, this.cols, this.flex, this.rows, {this.keys, this.acts});
  final Cell title;
  final List<Cell> cols;
  final List<double> flex;
  final List<List<Cell>> rows;

  /// Role of the account in each row. A row with a key can be opened in support mode.
  final List<String>? keys;

  /// Recent activity per row, Arabic and English, lines separated by '|'.
  final List<(String, String)>? acts;
}

class BarsBlock extends Block {
  const BarsBlock(this.title, this.items);
  final Cell title;
  final List<(Cell, double)> items;
}

class CardsBlock extends Block {
  const CardsBlock(this.title, this.items);
  final Cell title;
  final List<(Cell, Cell, String)> items;
}

class MapBlock extends Block {
  const MapBlock(this.title);
  final Cell title;
}

class AdminPage {
  const AdminPage(this.id, this.title, this.sub, this.blocks, {this.acts = const []});
  final String id;
  final Cell title, sub;
  final List<Block> blocks;
  final List<Cell> acts;
}

const adminNav = [
  (Cell('العمليات', 'Operations'), ['overview', 'live', 'pickups', 'drivers', 'warehouse']),
  (Cell('السوق', 'Marketplace'), ['lots', 'orders', 'requests']),
  (Cell('العملاء', 'Accounts'), ['accounts', 'users', 'businesses', 'buyers']),
  (Cell('المالية والنظام', 'Finance and system'), ['ledger', 'pricing', 'reports', 'support', 'audit', 'settings']),
];
