import controlP5.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import ddf.minim.effects.*;
import ddf.minim.ugens.*;
import javax.swing.filechooser.FileFilter;//librerias de elastic search
import javax.swing.filechooser.FileNameExtensionFilter;//librerias de elastic search
import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse; //librerias de elastic search
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;//librerias de elastic search
import org.elasticsearch.action.index.IndexRequest;//librerias de elastic search
import org.elasticsearch.action.index.IndexResponse;//librerias de elastic search
import org.elasticsearch.action.search.SearchResponse;//librerias de elastic search
import org.elasticsearch.action.search.SearchType;//librerias de elastic search
import org.elasticsearch.client.Client;//librerias de elastic search
import org.elasticsearch.common.settings.Settings;//librerias de elastic search
import org.elasticsearch.node.Node;//librerias de elastic search
import org.elasticsearch.node.NodeBuilder;//librerias de elastic search
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";

ControlP5 ui;//la vaina de los botones
ScrollableList list;
Minim minim;
AudioPlayer song;
AudioMetaData meta;
AudioInput in;

FFT fft;
Client client;
Node node;
HighPassSP highpass;//el UaUUUAuuuuuu
LowPassSP lowpass;//el UaUUUAuuuuuu bajo
BandPass bandpass;//el UaUUUAuuuuuu medio
LowPassFS   lpf;
Textlabel texto;
boolean si;

float[] buffer;
int ys = 25;
int yi = 15;
String autor="", titulo="";
boolean  mute=true;
boolean nada=false;
int Hpass;
int Lpass;
int Bpass;

void setup() {

  background(0);

  size(900, 300);
  minim = new Minim(this);
  ui = new ControlP5(this);
  Settings.Builder settings = Settings.settingsBuilder();

  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);
  node = NodeBuilder.nodeBuilder()
    .settings(settings)
    .clusterName("mycluster")
    .data(true)
    .local(true)
    .node();
  // Instancia de cliente de conexion al nodo de ElasticSearch
  client = node.client();

  // Esperamos a que el nodo este correctamente inicializado
  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  // Revisamos que nuestro indice (base de datos) exista
  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    // En caso contrario, se crea el indice
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }
  //.setImages(loadImage("pause.png"),loadImage("pause.png"),loadImage("pause.png")) para poner imagenes en los botonsinis
  ui.addButton("play").setPosition(60, 110).setSize(50, 100).setImages(loadImage("play.png"), loadImage("play.png"), loadImage("play.png"));
  ui.addButton("pause").setPosition(110, 110).setSize(50, 100).setImages(loadImage("pause.png"), loadImage("pause.png"), loadImage("pause.png"));
  ui.addButton("stop").setPosition(160, 110).setSize(50, 100).setImages(loadImage("stop.png"), loadImage("stop.png"), loadImage("stop.png"));

  ui.addButton("adelantar").setValue(0).setPosition(50, 130).setSize(50, 50).setImages(loadImage("anterior.png"), loadImage("anterior.png"), loadImage("anterior.png"));
  ui.addButton("atrasar").setValue(0).setPosition(110, 130).setSize(50, 50).setImages(loadImage("siguiente.png"), loadImage("siguiente.png"), loadImage("siguiente.png"));
  ui.addButton("importFiles").setLabel("Importar").setPosition(200, 0).setSize(50, 30).setImages(loadImage("importar.png"), loadImage("importar.png"), loadImage("importar.png"));

  ui.addSlider("Lpass").setPosition(350, 0).setSize(20, 100).setRange(3000, 20000).setValue(3000).setNumberOfTickMarks(30);  
  ui.getController("Lpass").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);
  ui.addSlider("Hpass").setPosition(300, 0).setSize(20, 100).setRange(0, 3000).setValue(0).setNumberOfTickMarks(30);  //las vainas  para ecualizador hsadjnak
  ui.getController("Hpass").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);
  ui.addSlider("Bpass").setPosition(400, 0).setSize(20, 100).setRange(100, 1000).setValue(100).setNumberOfTickMarks(30);
  ui.getController("Bpass").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);

  list = ui.addScrollableList("playlist").setPosition(0, 180).setSize(500, 300).setBarHeight(20).setItemHeight(20).setType(ScrollableList.LIST);//la lista de las musicas
  ui.addSlider("volumen").setRange(-40, 0).setValue(-20).setPosition(460, 0).setSize(10, 100); // la barisha del volumen 
  loadFiles();
}
//Hablarle a Welling para el AN firmado pls!
void draw() {
  PImage img;
  img = loadImage("si.jpg");//no se ve esta vaina T.T 
  if (song!= null)
  {

    lowpass.setFreq(Lpass);
    highpass.setFreq(Hpass);
    bandpass.setFreq(Bpass);
    stuff();
  }
  background(0);
  stroke(255);
  rect(500, 0, 10, 300);
  text("Titulo: " + titulo, 0, 10);
  text("Autor: " + autor, 0, 30);
  stuff();
}
//metodos 
public void play() 
{
  println("Play");
  meta = song.getMetaData();
  titulo = meta.title();
  autor = meta.author();
  song.play();
  //in= minim.getLineIn(Minim.STEREO, 512); //para fft
  fft = new FFT(song.bufferSize(), song.sampleRate());
}
public void pause() 
{
  println("Pause");
  song.pause();
}

public void stop() 
{
  println("Stop");
  song.close();
  song.pause();
  song.rewind();
}

public void atrasar() 
{
  println("Atrasar");
  song.skip(-500);
}
public void adelanto()
{
  println("Adelanto");
  song.skip(500);
}

void volumen(float v) 
{
  float  volumen = v;
  if (v==-40) {
    song.setGain(v);
    song.setGain(-60);
  } else { 
    song.setGain(v);
  }
}

public void fileSelected(File selection) 
{
  if (selection == null)
  {
    println("Seleccion cancelada");
  } else
  {
    println("User selected " + selection.getAbsolutePath());
    song = minim.loadFile(selection.getAbsolutePath(), 1024);
    highpass = new HighPassSP(300, song.sampleRate());
    song.addEffect(highpass);
    lowpass = new LowPassSP(300, song.sampleRate());
    song.addEffect(lowpass);
    bandpass = new BandPass(300, 300, song.sampleRate());
    song.addEffect(bandpass);
  }
}

void importFiles()
{
  // Selector de archivos
  JFileChooser jfc = new JFileChooser();
  // Agregamos filtro para seleccionar solo archivos .mp3
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  // Se permite seleccionar multiples archivos a la vez
  jfc.setMultiSelectionEnabled(true);
  // Abre el dialogo de seleccion
  jfc.showOpenDialog(null);
  // Iteramos los archivos seleccionados
  for (File f : jfc.getSelectedFiles()) 
  {
    // Si el archivo ya existe en el indice, se ignora
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) 
    {
      continue;
    }

    // Cargamos el archivo en la libreria minim para extrar los metadatos
    Minim minim = new Minim(this);
    AudioPlayer song = minim.loadFile(f.getAbsolutePath());
    AudioMetaData meta = song.getMetaData();

    // Almacenamos los metadatos en un hashmap
    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());

    try
    {
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();
      // Agregamos el archivo a la lista
      addItem(doc);
    } 
    catch(Exception e) 
    {
      e.printStackTrace();
    }
  }
}

void playlist(int n) 
{
  println(list.getItem(n));
  //println(list.getItem(n));
  if (song!=null)
  {
    song.pause();
  }
  Map<String, Object> value = (Map<String, Object>) list.getItem(n).get("value");
  println(value.get("path"));
  minim = new Minim(this);

  song = minim.loadFile((String)value.get("path"), 1024);
  fft = new FFT(song.bufferSize(), song.sampleRate());
  highpass = new HighPassSP(300, song.sampleRate());//alto
  song.addEffect(highpass);
  lowpass = new LowPassSP(300, song.sampleRate());//bajo
  song.addEffect(lowpass);
  bandpass = new BandPass(300, 300, song.sampleRate());//
  song.addEffect(bandpass);
  fft.logAverages(22, 10);
  meta = song.getMetaData();
  if (!meta.title().equals("")) 
  {
    texto.setText(meta.title()+"`\n"+meta.author());
    print("sale");
  } else 
  {
    texto.setText(meta.fileName());
    print("entra");
  }
  //song = min.loadFile(selection.getAbsolutePath(),1024);
}
void loadFiles() 
{
  try 
  {
    // Buscamos todos los documentos en el indice
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    // Se itera los resultados
    for (SearchHit hit : response.getHits().getHits())
    {
      // Cada resultado lo agregamos a la lista
      addItem(hit.getSource());
    }
  } 
  catch(Exception e)
  {
    e.printStackTrace();
  }
}
void addItem(Map<String, Object> doc) 
{
  // Se agrega a la lista. El primer argumento es el texto a desplegar en la lista, el segundo es el objeto que queremos que almacene
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
}
void stuff() 
{
  if (!nada) 
  {
    if (!(fft==null)) 
    {
      fft.forward(song.mix);
      stroke(random(255), random(255), random(255));
      for (int i = 0; i < fft.specSize(); i++)
      {
        line(510, 300, 900, 300 - fft.getBand(i)*4);
      }
    }
    fill(255);
    try 
    {
    }
    catch (Exception e)
    {
    }
    finally {
    }
  }
}