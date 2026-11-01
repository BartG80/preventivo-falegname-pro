import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class AppSettings {
  String nome = "Preventivo Falegname Pro";
  String piva = "";
  String iban = "IT60 X054 2811 1010 0000 0123 456";
  String bic = "BCITITMM";
  double tariffa = 35.0;
  Map<String, double> legni = {
    "Rovere": 180,
    "Noce": 250,
    "Abete": 90,
    "Faggio": 120
  };
  Map<String, Map<String, double>> finiture = {
    "Cera": {"Naturale": 15},
    "Oli": {"Lino": 25, "Tung": 32},
    "Impregnanti": {"all'acqua": 18, "sintetico": 22},
    "Smalti": {"all'acqua": 24, "sintetico": 28},
    "Turapori": {"Standard": 12},
    "Protettivi antigraffio": {
      "all'acqua": 35,
      "sintetico": 40,
      "bicomponente": 65
    },
  };
  bool isPro = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString("preventivo_falegname_pro_v1");
    if (s != null) {
      try {
        final m = jsonDecode(s);
        nome = m['nome'] ?? "Preventivo Falegname Pro";
        piva = m['piva'] ?? "";
        iban = m['iban'] ?? iban;
        tariffa = (m['tariffa'] as num?)?.toDouble() ?? 35.0;
        isPro = m['isPro'] ?? false;
      } catch (e) {}
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        "preventivo_falegname_pro_v1",
        jsonEncode({
          "nome": nome,
          "piva": piva,
          "iban": iban,
          "tariffa": tariffa,
          "isPro": isPro
        }));
  }
}

final settings = AppSettings();

class LogoService {
  static Future<File?> getFile() async {
    final d = await getApplicationDocumentsDirectory();
    final f = File("${d.path}/logo.png");
    return await f.exists() ? f : null;
  }
  static Future<void> save(XFile x) async {
    final d = await getApplicationDocumentsDirectory();
    await File(x.path).copy("${d.path}/logo.png");
  }
}

class Finitura {
  String cat, varia;
  double costo;
  Finitura({required this.cat, required this.varia, required this.costo});
}

class Lavoro {
  String cliente, desc, misure, tipoLegno;
  double ore;
  List<Finitura> finiture;
  Lavoro(
      {required this.cliente,
      required this.desc,
      this.misure = "120x60",
      this.tipoLegno = "Rovere",
      this.ore = 14,
      List<Finitura>? finiture})
      : finiture = finiture ?? [];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settings.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A2A5E))),
        home: const Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Lavoro> lavori = [
    Lavoro(cliente: "Mario Rossi", desc: "Mensola su misura Rovere"),
    Lavoro(cliente: "Bianchi", desc: "Libreria")
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(settings.nome),
            backgroundColor: const Color(0xFF0A2A5E),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Profilo()))
                      .then((_) => setState(() {})))
            ]),
        floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF0A2A5E),
            foregroundColor: Colors.white,
            onPressed: () => setState(
                () => lavori.add(Lavoro(cliente: "Nuovo", desc: "Nuovo lavoro"))),
            child: const Icon(Icons.add)),
        body: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lavori.length,
            itemBuilder: (c, i) {
              final l = lavori[i];
              final tot = (settings.legni[l.tipoLegno] ?? 0) +
                  l.ore * settings.tariffa +
                  l.finiture.fold(0.0, (s, f) => s + f.costo);
              return Card(
                  child: ListTile(
                      title: Text(l.cliente),
                      subtitle: Text("${l.desc} - ${tot.toStringAsFixed(2)}â¬"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => Dettaglio(lavoro: l)))
                          .then((_) => setState(() {}))));
            }));
  }
}

class Dettaglio extends StatefulWidget {
  final Lavoro lavoro;
  const Dettaglio({super.key, required this.lavoro});
  @override
  State<Dettaglio> createState() => _DettaglioState();
}

class _DettaglioState extends State<Dettaglio> {
  late TextEditingController misure, ore;
  late String tipo;
  @override
  void initState() {
    super.initState();
    misure = TextEditingController(text: widget.lavoro.misure);
    ore = TextEditingController(text: widget.lavoro.ore.toString());
    tipo = settings.legni.containsKey(widget.lavoro.tipoLegno)
        ? widget.lavoro.tipoLegno
        : settings.legni.keys.first;
  }

  Future<void> addFinitura() async {
    String? c, v;
    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
                    title: const Text("Finitura"),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButton<String>(
                          value: c,
                          hint: const Text("Categoria"),
                          isExpanded: true,
                          items: settings.finiture.keys
                              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                          onChanged: (x) => setD(() => c = x)),
                      if (c != null)
                        DropdownButton<String>(
                            value: v,
                            hint: const Text("Variante"),
                            isExpanded: true,
                            items: settings.finiture[c]!.keys
                                .map((k) => DropdownMenuItem(
                                    value: k,
                                    child: Text("$k - ${settings.finiture[c]![k]}â¬")))
                                .toList(),
                            onChanged: (x) => setD(() => v = x))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Chiudi")),
                      ElevatedButton(
                          onPressed: () {
                            if (c != null && v != null) {
                              setState(() => widget.lavoro.finiture.add(Finitura(
                                  cat: c!,
                                  varia: v!,
                                  costo: settings.finiture[c]![v]!)));
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text("Aggiungi"))
                    ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Dettaglio")),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: misure,
                  decoration: const InputDecoration(
                      labelText: "Misure es. 120x60",
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                  value: tipo,
                  decoration: const InputDecoration(
                      labelText: "Legno", border: OutlineInputBorder()),
                  items: settings.legni.keys
                      .map((k) => DropdownMenuItem(
                          value: k, child: Text("$k - ${settings.legni[k]}â¬")))
                      .toList(),
                  onChanged: (x) => setState(() => tipo = x!)),
              const SizedBox(height: 12),
              TextField(
                  controller: ore,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: "Ore x ${settings.tariffa}â¬/h",
                      border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Finiture",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: addFinitura, icon: const Icon(Icons.add_circle))
                  ]),
              Wrap(
                  spacing: 8,
                  children: widget.lavoro.finiture
                      .map((f) => Chip(
                          label: Text("${f.cat} ${f.varia}"),
                          onDeleted: () =>
                              setState(() => widget.lavoro.finiture.remove(f))))
                      .toList()),
              const Spacer(),
              SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2A5E),
                          foregroundColor: Colors.white),
                      onPressed: () {
                        widget.lavoro.misure = misure.text;
                        widget.lavoro.tipoLegno = tipo;
                        widget.lavoro.ore = double.tryParse(ore.text) ?? 0;
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => Preventivo(lavoro: widget.lavoro)));
                      },
                      child: const Text("Vedi Preventivo")))
            ])));
  }
}

class Preventivo extends StatelessWidget {
  final Lavoro lavoro;
  const Preventivo({super.key, required this.lavoro});

  Future<void> pdf() async {
    final doc = pw.Document();
    final logo = await LogoService.getFile();
    pw.MemoryImage? img;
    if (logo != null) img = pw.MemoryImage(await logo.readAsBytes());

    final mat = settings.legni[lavoro.tipoLegno] ?? 0;
    final man = lavoro.ore * settings.tariffa;
    final fin = lavoro.finiture.fold(0.0, (s, f) => s + f.costo);
    final sub = mat + man + fin;
    final iva = sub * 0.22;
    final tot = sub + iva;

    final navy = PdfColor.fromHex("#0A2A5E");
    final lightGrey = PdfColor.fromHex("#F5F5F5");

    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (c) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // HEADER
                  pw.Container(
                      color: navy,
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(18),
                      child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(settings.nome,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 16)),
                            pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text("P.IVA ${settings.piva}",
                                      style: const pw.TextStyle(
                                          color: PdfColors.white, fontSize: 8)),
                                  pw.Text("Email: info@preventivo-pro.it",
                                      style: const pw.TextStyle(
                                          color: PdfColors.white, fontSize: 8)),
                                ])
                          ])),
                  pw.SizedBox(height: 20),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("PREVENTIVO",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 22,
                                color: navy)),
                        pw.Text("Data: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                            style: const pw.TextStyle(fontSize: 10))
                      ]),
                  pw.Divider(color: navy),
                  pw.Text("Cliente: ${lavoro.cliente}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("Lavoro: ${lavoro.desc} - Misure: ${lavoro.misure}"),
                  pw.SizedBox(height: 12),
                  // Tabella
                  pw.Table(
                      border: pw.TableBorder.all(color: navy, width: 0.8),
                      children: [
                        pw.TableRow(
                            decoration: pw.BoxDecoration(color: navy),
                            children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text("Descrizione",
                                      style: const pw.TextStyle(
                                          color: PdfColors.white))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text("Importo",
                                      style: const pw.TextStyle(
                                          color: PdfColors.white))),
                            ]),
                        pw.TableRow(children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                  "${lavoro.tipoLegno} - ${lavoro.misure}")),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text("${mat.toStringAsFixed(2)}â¬")),
                        ]),
                        pw.TableRow(children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                  "Manodopera ${lavoro.ore}h x ${settings.tariffa}â¬")),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text("${man.toStringAsFixed(2)}â¬")),
                        ]),
                        ...lavoro.finiture.map((f) => pw.TableRow(children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text("${f.cat} ${f.varia}")),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text("${f.costo.toStringAsFixed(2)}â¬")),
                            ])),
                      ]),
                  pw.SizedBox(height: 12),
                  pw.Container(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("Subtotale: ${sub.toStringAsFixed(2)}â¬"),
                            pw.Text("IVA 22%: ${iva.toStringAsFixed(2)}â¬"),
                            pw.Divider(),
                            pw.Text("TOTALE: ${tot.toStringAsFixed(2)}â¬",
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 18,
                                    color: navy)),
                          ])),
                  pw.Spacer(),
                  // FOOTER con IBAN
                  pw.Container(
                      color: navy,
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                "${settings.nome} - P.IVA ${settings.piva} | IBAN: ${settings.iban} | BIC: ${settings.bic}",
                                style: const pw.TextStyle(
                                    color: PdfColors.white, fontSize: 7)),
                            pw.SizedBox(height: 3),
                            pw.Text(
                                "CONDIZIONI DI PAGAMENTO: 30% acconto alla conferma - 70% a saldo alla consegna - Pagamento tramite Bonifico Bancario",
                                style: const pw.TextStyle(
                                    color: PdfColors.white, fontSize: 7)),
                            pw.Text(
                                "ValiditÃ  preventivo: 30 giorni - Tempi di realizzazione: 10-15 giorni lavorativi",
                                style: const pw.TextStyle(
                                    color: PdfColors.white, fontSize: 6)),
                          ]))
                ])));

    await Printing.sharePdf(
        bytes: await doc.save(), filename: "preventivo_falegname_pro.pdf");
  }

  @override
  Widget build(BuildContext context) {
    final tot = (settings.legni[lavoro.tipoLegno] ?? 0) +
        lavoro.ore * settings.tariffa +
        lavoro.finiture.fold(0.0, (s, f) => s + f.costo);
    return Scaffold(
        appBar: AppBar(
            title: const Text("Preventivo"),
            backgroundColor: const Color(0xFF0A2A5E),
            foregroundColor: Colors.white),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Totale: ${(tot * 1.22).toStringAsFixed(2)}â¬ IVA incl.",
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("IBAN: ${settings.iban} - ${settings.bic}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2A5E),
                              foregroundColor: Colors.white),
                          onPressed: pdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("Condividi PDF con IBAN")))
                ])));
  }
}

class Profilo extends StatefulWidget {
  const Profilo({super.key});
  @override
  State<Profilo> createState() => _ProfiloState();
}

class _ProfiloState extends State<Profilo> {
  late TextEditingController nome, piva, iban, tariffa;
  File? logo;
  @override
  void initState() {
    super.initState();
    nome = TextEditingController(text: settings.nome);
    piva = TextEditingController(text: settings.piva);
    iban = TextEditingController(text: settings.iban);
    tariffa = TextEditingController(text: settings.tariffa.toString());
    LogoService.getFile().then((f) => setState(() => logo = f));
  }

  Future<void> pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      await LogoService.save(x);
      logo = await LogoService.getFile();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Profilo")),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
              child: GestureDetector(
                  onTap: pick,
                  child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(12)),
                      child: logo != null
                          ? Image.file(logo!)
                          : const Icon(Icons.add_a_photo)))),
          const SizedBox(height: 16),
          TextField(
              controller: nome,
              decoration: const InputDecoration(
                  labelText: "Nome AttivitÃ  (Preventivo Falegname Pro)",
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: piva,
              decoration: const InputDecoration(
                  labelText: "P.IVA", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: iban,
              decoration: const InputDecoration(
                  labelText: "IBAN", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: tariffa,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Tariffa oraria", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () async {
                settings.nome = nome.text;
                settings.piva = piva.text;
                settings.iban = iban.text;
                settings.tariffa = double.tryParse(tariffa.text) ?? 35;
                await settings.save();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("SALVA")),
        ]));
  }
}
