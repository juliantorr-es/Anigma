import Theme from 'vitepress/theme'
import type { Theme as ThemeShape } from 'vitepress'
import ProjectStatus from './components/ProjectStatus.vue'
import ArchitectureOverview from './components/ArchitectureOverview.vue'
import DiagramShowcase from './components/DiagramShowcase.vue'
import ModuleExplorer from './components/ModuleExplorer.vue'
import RelationshipMapper from './components/RelationshipMapper.vue'
import HealthDashboard from './components/Phase3/HealthDashboard.vue'

const CustomTheme: ThemeShape = {
  ...Theme,
  enhanceApp({ app }) {
    app.component('ProjectStatus', ProjectStatus)
    app.component('ArchitectureOverview', ArchitectureOverview)
    app.component('DiagramShowcase', DiagramShowcase)
    app.component('ModuleExplorer', ModuleExplorer)
    app.component('RelationshipMapper', RelationshipMapper)
    app.component('HealthDashboard', HealthDashboard)
    Theme.enhanceApp?.({ app })
  }
}

export default CustomTheme
