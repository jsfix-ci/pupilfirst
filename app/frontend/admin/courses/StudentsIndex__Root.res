let str = React.string

open StudentsIndex__Types

module Item = {
  type t = StudentInfo.t
}

module PagedStudents = Pagination.Make(Item)

type state = {
  loading: LoadingV2.t,
  students: PagedStudents.t,
  levels: array<Level.t>,
  totalEntriesCount: int,
}

type action =
  | LoadStudents(option<string>, bool, array<StudentInfo.t>, int)
  | BeginLoadingMore
  | BeginReloading

let reducer = (state, action) =>
  switch action {
  | LoadStudents(endCursor, hasNextPage, students, totalEntriesCount) =>
    let updatedStudent = switch state.loading {
    | LoadingMore => Js.Array2.concat(PagedStudents.toArray(state.students), students)
    | Reloading(_) => students
    }

    {
      ...state,
      students: PagedStudents.make(updatedStudent, hasNextPage, endCursor),
      loading: LoadingV2.setNotLoading(state.loading),
      totalEntriesCount,
    }
  | BeginLoadingMore => {...state, loading: LoadingMore}
  | BeginReloading => {...state, loading: LoadingV2.setReloading(state.loading)}
  }

module CourseStudentsQuery = %graphql(`
    query CourseStudentsQuery($courseId: ID!, $after: String, $filterString: String) {
      courseStudents(courseId: $courseId, filterString: $filterString,first: 20, after: $after) {
        nodes {
          id
          taggings
          user {
            id
            name
            email
            avatarUrl
            title
            affiliation
            taggings
          }
          level {
            id
            name
            number
          }
          cohort {
            id
            name
            description
            endsAt
          }
        }
        pageInfo {
          endCursor,
          hasNextPage
        }
        totalCount
      }
    }
  `)

let getStudents = (send, courseId, cursor, params) => {
  let filterString = Webapi.Url.URLSearchParams.toString(params)

  CourseStudentsQuery.makeVariables(
    ~courseId,
    ~after=?cursor,
    ~filterString=?Some(filterString),
    (),
  )
  |> CourseStudentsQuery.make
  |> Js.Promise.then_(response => {
    send(
      LoadStudents(
        response["courseStudents"]["pageInfo"]["endCursor"],
        response["courseStudents"]["pageInfo"]["hasNextPage"],
        Js.Array.map(StudentInfo.makeFromJS, response["courseStudents"]["nodes"]),
        response["courseStudents"]["totalCount"],
      ),
    )
    Js.Promise.resolve()
  })
  |> ignore
}

let computeInitialState = () => {
  loading: LoadingV2.empty(),
  students: Unloaded,
  levels: [],
  totalEntriesCount: 0,
}

let reloadStudents = (courseId, send, params) => {
  send(BeginReloading)
  getStudents(send, courseId, None, params)
}

// let pageTitle = (courses, courseId) => {
//   let currentCourse = ArrayUtils.unsafeFind(
//     course => AppRouter__Course.id(course) == courseId,
//     "Could not find currentCourse with ID " ++ courseId ++ " in CoursesReview__Root",
//     courses,
//   )

//   `${tc("review")} | ${AppRouter__Course.name(currentCourse)}`
// }

let onSelect = (key, value, params) => {
  Webapi.Url.URLSearchParams.set(key, value, params)
  RescriptReactRouter.push("?" ++ Webapi.Url.URLSearchParams.toString(params))
}

let showTag = (~value=?, key, text, color, params) => {
  let paramsValue = Belt.Option.getWithDefault(value, text)
  <button
    key={text}
    className={"rounded-lg mt-1 mr-1 py-px px-2 text-xs font-semibold focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 " ++
    color}
    onClick={_e => onSelect(key, paramsValue, params)}>
    {text->str}
  </button>
}

let studentsList = (students, courseId, params) => {
  <div className="space-y-4">
    {students
    ->Js.Array2.map(student => {
      <div key={StudentInfo.id(student)} className="h-full flex items-center bg-white">
        <div className="flex flex-1 items-center text-left justify-between rounded-md shadow">
          <div className="flex py-4 px-4">
            <div className="text-sm flex items-center space-x-4">
              <img
                className="inline-block h-12 w-12 rounded-full"
                src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80"
                alt=""
              />
              <div>
                <Link
                  href={`/school/courses/${courseId}/students/${StudentInfo.id(student)}/edit`}
                  className="font-semibold inline-block hover:underline hover:text-primary-500 transition ">
                  {User.name(StudentInfo.user(student))->str}
                </Link>
                <div className="flex flex-row mt-1">
                  <div className="flex flex-wrap">
                    {showTag(
                      "cohort",
                      Cohort.name(StudentInfo.cohort(student)),
                      "bg-green-100 text-green-900",
                      params,
                      ~value=Cohort.filterValue(StudentInfo.cohort(student)),
                    )}
                    {showTag(
                      "level",
                      Level.shortName(StudentInfo.level(student)),
                      "bg-yellow-100 text-yellow-900",
                      params,
                      ~value=Level.filterValue(StudentInfo.level(student)),
                    )}
                    {StudentInfo.taggings(student)
                    ->Js.Array2.map(tag => {
                      showTag("student_tags", tag, "bg-gray-200 text-gray-900", params)
                    })
                    ->React.array}
                    {User.taggings(StudentInfo.user(student))
                    ->Js.Array2.map(tag => {
                      showTag("user_tags", tag, "bg-blue-100 text-blue-900", params)
                    })
                    ->React.array}
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div>
            <Link
              href={`/school/courses/${courseId}/students/${StudentInfo.id(student)}/details`}
              className="flex flex-1 items-center text-left py-4 px-4 hover:bg-gray-100 hover:text-primary-500 focus:bg-gray-100 focus:text-primary-500 justify-between">
              <span className="inline-flex items-center p-2">
                <PfIcon className="if i-edit-regular if-fw" />
                <span className="ml-2"> {"Edit"->str} </span>
              </span>
            </Link>
          </div>
        </div>
      </div>
    })
    ->React.array}
  </div>
}

let makeFilters = () => {
  [
    CourseResourcesFilter.makeFilter("cohort", "Cohort", DataLoad(#Cohort), "green"),
    CourseResourcesFilter.makeFilter(
      "include_inactive_students",
      "Include",
      Custom("Inactive Students"),
      "orange",
    ),
    CourseResourcesFilter.makeFilter("level", "Level", DataLoad(#Level), "yellow"),
    CourseResourcesFilter.makeFilter(
      "student_tags",
      "Student Tags",
      DataLoad(#StudentTag),
      "indigo",
    ),
    CourseResourcesFilter.makeFilter("user_tags", "User Tags", DataLoad(#UserTag), "blue"),
    CourseResourcesFilter.makeFilter("email", "Search by Email", Search, "gray"),
    CourseResourcesFilter.makeFilter("name", "Search by Name", Search, "gray"),
  ]
}

@react.component
let make = (~courseId, ~search) => {
  let (state, send) = React.useReducer(reducer, computeInitialState())
  let params = Webapi.Url.URLSearchParams.make(search)
  React.useEffect1(() => {
    reloadStudents(courseId, send, params)
    None
  }, [search])

  <>
    <Helmet>
      <title> {str("Students Index")} </title>
    </Helmet>
    <div>
      <div>
        <div className="max-w-4xl 2xl:max-w-5xl mx-auto px-4 mt-8">
          <div className="flex justify-between items-center gap-2">
            <ul className="flex font-semibold text-sm">
              <li
                className="px-3 py-3 md:py-2 text-primary-500 border-b-3 border-primary-500 -mb-px">
                <span> {"Active Students"->str} </span>
              </li>
            </ul>
            <div>
              <Link
                className="btn btn-primary btn-large"
                href={`/school/courses/${courseId}/students/new`}>
                <span> {str("Create Student")} </span>
              </Link>
            </div>
          </div>
          <div className="sticky top-0 my-6">
            <div className="border rounded-lg mx-auto bg-white ">
              <div>
                <div className="flex w-full items-start p-4">
                  <CourseResourcesFilter courseId filters={makeFilters()} search={search} />
                  {"sorter"->str}
                </div>
              </div>
            </div>
          </div>
          <div>
            {switch state.students {
            | Unloaded =>
              <div> {SkeletonLoading.multiple(~count=6, ~element=SkeletonLoading.card())} </div>
            | PartiallyLoaded(students, cursor) =>
              <div>
                {studentsList(students, courseId, params)}
                {switch state.loading {
                | LoadingMore =>
                  <div> {SkeletonLoading.multiple(~count=1, ~element=SkeletonLoading.card())} </div>
                | Reloading(times) =>
                  ReactUtils.nullUnless(
                    <div className="pb-6">
                      <button
                        className="btn btn-primary-ghost cursor-pointer w-full"
                        onClick={_ => {
                          send(BeginLoadingMore)
                          getStudents(send, courseId, Some(cursor), params)
                        }}>
                        {"Load More"->str}
                      </button>
                    </div>,
                    ArrayUtils.isEmpty(times),
                  )
                }}
              </div>
            | FullyLoaded(students) => <div> {studentsList(students, courseId, params)} </div>
            }}
          </div>
          {PagedStudents.showLoading(state.students, state.loading)}
        </div>
      </div>
    </div>
  </>
}
