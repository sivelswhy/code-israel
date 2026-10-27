import { BackButton } from './App'

const DATASETS = [
  { lang: 'Hébreu (texte officiel de référence)', url: 'https://data.gov.il/dataset/tqhe' },
  { lang: 'Français', url: 'https://data.gov.il/dataset/tqfr' },
  { lang: 'Anglais', url: 'https://data.gov.il/dataset/tqen' },
]

export function Sources({ onBack }: { onBack: () => void }) {
  return (
    <main className="page prose">
      <BackButton onClick={onBack} />
      <h1 className="title">Sources et licence</h1>

      <h2>D'où viennent les questions</h2>
      <p>
        Toutes les questions, réponses et illustrations proviennent de la banque officielle de l'examen théorique
        informatisé, publiée par le <strong>ministère des Transports et de la Sécurité routière de l'État d'Israël</strong>{' '}
        (משרד התחבורה והבטיחות בדרכים) sur le portail gouvernemental de données ouvertes data.gov.il.
      </p>
      <ul>
        {DATASETS.map((d) => (
          <li key={d.url}>
            {d.lang} : <a href={d.url} target="_blank" rel="noreferrer">{d.url.replace('https://', '')}</a>
          </li>
        ))}
      </ul>
      <p>
        Les illustrations sont les images officielles associées à chaque question, hébergées par le ministère sur{' '}
        <a href="https://www.gov.il" target="_blank" rel="noreferrer">gov.il</a>.
      </p>

      <h2>Licence</h2>
      <p>
        Ces jeux de données sont publiés sous licence{' '}
        <a href="https://data.gov.il/dataset/tqfr" target="_blank" rel="noreferrer">
          Creative Commons Attribution
        </a>
        . Réutilisation autorisée avec mention de la source : « Ministère des Transports d'Israël — data.gov.il ».
      </p>

      <h2>Traduction française</h2>
      <p>
        La version hébraïque fait foi : c'est celle de l'examen et la plus à jour. La traduction française officielle
        étant ancienne et parfois approximative, les textes français de cette application ont été révisés à partir de
        l'original hébreu. Chaque question permet d'afficher le texte hébreu officiel pour vérification.
      </p>

      <h2>Avertissement</h2>
      <p>
        Cette application n'est ni éditée ni approuvée par le ministère des Transports. Le format d'examen simulé
        (30 questions, 40 minutes, 4 erreurs maximum) reprend celui de l'examen informatisé ; la répartition des thèmes
        est proportionnelle à la banque et peut différer du tirage réel. En cas de doute, seul le texte officiel compte.
      </p>
    </main>
  )
}
